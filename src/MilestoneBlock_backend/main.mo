import Nat "mo:base/Nat";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Time "mo:base/Time";

import Constants "./modules/static/Constants";
import Errors "./modules/static/Errors";
import Types "./modules/static/Types";

import PIdContext "./modules/PIdContext";
import UsersMetadata "./modules/UsersMetadata";
import UsersGoals "./modules/UsersGoals";

// note here the "original" caller (the principal that deployed this canister)
// is reassigned as to prevent accidental reuse in subsequent shared modified calls
shared ({ caller = installer }) actor class() = this {

  ////////////////////////////////////////// Method Listing:
  // authenticateWithUserAccountCreationIfNecessary
  // authenticate -> userId

  // getUserMetadata
  // updateUserMetadata

  // addNewUnscheduledGoal
  // addNewScheduledGoal
  // addNewActiveGoal
  
  // editGoalMetadataOrContent

  // scheduleUnscheduledGoal
  // rescheduleScheduledGoal
  // unscheduleScheduledGoal

  // activateExistingGoal
  // completeActiveGoal
  
  // removeExistingGoal

  // getTotalCreatedGoalCount

  // "stable" modifier is used to desiginate that variable to have the quality of orthogonal persistence, which is
  // another way of saying if the canister is upgraded, that variable will retain its value whereas non-stable variables will not. 
  // another way to say explain this is that stable variables can be reliably serialized 
  // not all variables have a stable form, in fact if a variable is compound and has private fields, it cannot be 
  // reliably serialized and is not stable (such as a hashmap, althought there is a stable hashmap implementation available)

  // also note that fields followed by an underscore are a reminder that is private to the class/file

  // the "next" used and incremented each time a new account is allocated
  stable var monotonicIdCreationCount_: Nat = 0;
  
  // variables used to migrate data between canister upgrades (see below)
  stable var pidStableState_: Types.PIdContextStableState = [];
  stable var usersMetadataStableState_: Types.UsersMetadataStableState = [];
  stable var usersGoalsStableState_: Types.UsersGoalsStableState = [];

  // the next three declarations are the primary units of this file, each is a mapping from 
  // the id to the respective data type (principal > id, id > metadata, id > goals) that 
  // handles all the functionality needed. to do: add get/set to each so that the underlying map 
  // structure can be swapped out to whatever's more suitable (ie stablehashmap, or other structure)

  // class based module wrapper that maps principal to the id used to subsequently do any CRUD related calls, 
  // so each shared call in this file first passes its shared { caller } to the authenticator, which will return the id associated with that principal 
  let authenticator_: PIdContext.Authenticator = PIdContext.Authenticator(monotonicIdCreationCount_, pidStableState_);

  // class based module wrapper for handling all the logic related to users' "profile" functionality
  let users_: UsersMetadata.UsersMetadata = UsersMetadata.UsersMetadata(usersMetadataStableState_);

  // class based module wrapper for handling all the logic related to users' goals functionality
  let goals_: UsersGoals.UsersGoals = UsersGoals.UsersGoals(usersGoalsStableState_);

  // when canister is deployed, it processes the canister's code. when it is deployed again, so that
  // it is upgraded, this callback is triggered first which is used serialize any non-stable data to a 
  // stable form for that data. then the entire canister's code is run again, so that the
  // three declarations above are invoked, passing the stable data to their respective constructors
  // note this is why only half the available canister memory is used, since whatever must be serialized during
  // upgrade must temporarily be allocated as stable. Note that if all declarations were stable, this
  // would not have to happen
  system func preupgrade() {
    monotonicIdCreationCount_ := authenticator_.getMonotonicIdCreationCount();
    pidStableState_ := authenticator_.getEntries();
    usersMetadataStableState_ := users_.getEntries();
    usersGoalsStableState_ := goals_.getEntries();
  };

  // after the canister has been deployed so it has upgraded, so that preupgrade and the class code is
  // ran, this will be called at the end (ie, as if it were declared at the file scope at the very end of the file)
  // hence it is used for cleanup or deallocated whatever was serialized above
  system func postupgrade() {
    pidStableState_ := [];
    usersMetadataStableState_ := [];
    usersGoalsStableState_ := [];
  };

  // in web3, where a user can login with their wallet, they don't need to create a new account. this method is called
  // when a user first logs in, to verify if any allocation needs to take place. possibly a better way to do this
  // with another form of lazy instantiation; also, could split this into a query and non-query method, since this
  // only needs to be performed once per new user call
  public shared({ caller }) func authenticateWithUserAccountCreationIfNecessary(): async Result.Result<Types.UniqueId, Text> {
    let size = authenticator_.getEntries().size();
    if (caller == Constants.getAnonymousPrincipal()) { return #err(Errors.AnonUnauthorized); };
    if (not (authenticator_.isKnownPrincipal(caller))) {
      let combineInitCalls = func(forPrincipal: Principal): Types.UniqueId {
        let createdId: Types.UniqueId = authenticator_.persistNewId(caller); 
        users_.initializeNewUserMetadata(createdId, caller);
        goals_.initializeNewUserGoals(createdId);
        return createdId;
      };
      let createdUserId = combineInitCalls(caller);
    };
    let authId = authenticator_.authenticate(caller);
    return #ok(authId # " " # Principal.toText(caller));
  };

  public shared query({ caller }) func queryUserMetadata(): async Result.Result<Types.UserMetadata, Text> {
    return users_.getUserMetadata(authenticator_.authenticate(caller));
  };

  public shared({ caller }) func updateUserMetadata({ 
    preferredDisplayNameIn: ?Text; 
    emailAddressIn: ?Text 
  }): async Result.Result<Types.UserMetadata, Text> {
    return users_.persistUserMetadataEdits(authenticator_.authenticate(caller), preferredDisplayNameIn, emailAddressIn);
  };

  public shared query({ caller }) func queryAllGoalsOfUser(): async Result.Result<[Types.Goal], Text> {
    return #ok(goals_.getSpecificUserGoals(authenticator_.authenticate(caller)));
  };

  public shared query({ caller }) func querySpecificGoalOfUser({ goalIdIn: Types.UniqueId }): async Result.Result<Types.Goal, Text> {
    return goals_.getSpecificUserGoal(authenticator_.authenticate(caller), goalIdIn);
  };

  public shared({ caller }) func updateSpecificGoalMetadataOrContent({ 
    goalIdIn: Types.UniqueId; 
    titleIn: ?Text; 
    contentIn: ?Text; 
    tagsIn: ?[Text] 
  }): async Result.Result<Types.Goal, Text> {
    return (goals_.editGoalMetadataOrContent(authenticator_.authenticate(caller), goalIdIn, titleIn, contentIn, tagsIn));
  };

  // connects UsersMetadata to UsersGoals when a user creates a new goal to get the "next" (user specific goal creation count)
  // used to create the id of that goal
  func getNextGoalIdForUserId_(forUserId: Types.UniqueId): Types.UniqueId {
    return Nat.toText(users_.incrementSetAndGetUserMonotonicCreateGoalCount(forUserId));
  };

  // NOTE on the next three methods!
  // the next three methods were originally declared intended to make it simpler for the client to create a goal
  // however, "enumerating the options" like this might be less desirable than a single endpoint for goal creation
  public shared({ caller }) func addNewUnscheduledGoal({ 
    titleIn: ?Text; 
    contentIn: ?Text; 
    tagsIn: ?[Text] 
  }): async Result.Result<Types.Goal, Text> {
    let authdId = authenticator_.authenticate(caller);
    return goals_.addNewUnscheduledGoal(authdId, getNextGoalIdForUserId_(authdId), titleIn, contentIn, tagsIn);
  };

  public shared({ caller }) func addNewScheduledGoal({ 
    titleIn: ?Text; 
    contentIn: ?Text; 
    tagsIn: ?[Text]; 
    scheduledStartTime: Time.Time; 
    scheduledStopTime: Time.Time 
  }): async Result.Result<Types.Goal, Text> {
    let authdId = authenticator_.authenticate(caller);
    return goals_.addNewScheduledGoal(authdId, getNextGoalIdForUserId_(authdId), titleIn, contentIn, tagsIn, scheduledStartTime, scheduledStopTime);
  };

  public shared({ caller }) func addNewActiveGoal({ 
    titleIn: ?Text; 
    contentIn: ?Text; 
    tagsIn: ?[Text] 
  }): async Result.Result<Types.Goal, Text> {
    let authdId = authenticator_.authenticate(caller);
    return goals_.addNewActiveGoal(authdId, getNextGoalIdForUserId_(authdId), titleIn, contentIn, tagsIn);
  };

  public shared({ caller }) func scheduledUnscheduledGoal({ 
    goalIdIn: Types.UniqueId; 
    scheduledStartTime: Time.Time; 
    scheduledStopTime: Time.Time 
  }): async Result.Result<Types.Goal, Text> {
    let authdId = authenticator_.authenticate(caller);
    return goals_.scheduleUnscheduledGoal(authdId, goalIdIn, scheduledStartTime, scheduledStopTime);
  };  

  public shared({ caller }) func rescheduleScheduledGoal({ 
    goalIdIn: Types.UniqueId; 
    newScheduledStartTime: Time.Time; 
    newScheduledStopTime: Time.Time 
  }): async Result.Result<Types.Goal, Text> {
    let authdId = authenticator_.authenticate(caller);
    return goals_.rescheduleScheduledGoal(authdId, goalIdIn, newScheduledStartTime, newScheduledStopTime);
  };  

  public shared({ caller }) func activateScheduledOrUnscheduledGoal({ 
    goalIdIn: Types.UniqueId 
  }): async Result.Result<Types.Goal, Text> {
    let authdId = authenticator_.authenticate(caller);
    return goals_.activateExistingGoal(authdId, goalIdIn);
  };

  public shared({ caller }) func completeActiveGoal({ 
    goalIdIn: Types.UniqueId 
  }): async Result.Result<Types.Goal, Text> {
    let authdId = authenticator_.authenticate(caller);
    return goals_.completeActiveGoal(authdId, goalIdIn);
  };

  public shared({ caller }) func removeExistingGoal({ 
    goalIdIn: Types.UniqueId 
  }): async Result.Result<(Text, Types.UniqueId), Text> {
    let authdId = authenticator_.authenticate(caller);
    return goals_.removeExistingGoal(authdId, goalIdIn);
  };
  
  public shared({ caller }) func unscheduleScheduledGoal({ 
    goalInIn: Types.UniqueId 
  }): async Result.Result<Types.Goal, Text> {
    let authdId = authenticator_.authenticate(caller);
    return goals_.unscheduleScheduledGoal(authdId, goalInIn);
  };

  // note there's no shared({ caller }) here since it is not specific to any user, that is, it'll return the total number of goals
  // created by all users and doesn't require authentication to access. As it does not cause any state change in the canister, 
  // the query modifer can be added which speeds up response by not requiring the nodes to come to consensus
  public query func getTotalCreatedGoalCount(): async Nat {
    return goals_.getCountOfAllGoals();
  };
}