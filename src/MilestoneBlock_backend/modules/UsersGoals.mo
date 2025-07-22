import Array "mo:base/Array";
import Bool "mo:base/Bool";
import Buffer "mo:base/Buffer";
import HashMap "mo:base/HashMap";
import Int "mo:base/Int";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Option "mo:base/Option";
import Prelude "mo:base/Prelude";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Time "mo:base/Time";

import Constants "./static/Constants";
import Errors "./static/Errors";
import Types "./static/Types";

module {
  // class wrapper for handling all users' goals
  public class UsersGoals(initSet: Types.UsersGoalsStableState) {

    var userIdToGoalsMap_ = HashMap.fromIter<Types.UniqueId, [Types.Goal]>(
      initSet.vals(), initSet.size(), Text.equal, Text.hash
    );

    // non assertive boolean to see if the user id has a corresponding [goal]
    func userIdMaps_(forUniqueUserId: Types.UniqueId): Bool { 
      Option.isSome(userIdToGoalsMap_.get(forUniqueUserId)) 
    };

    // non assertive boolean to see if the goal id exists in the [goal]
    func goalIdExistsInGoalSet_(goalsSearchSet: [Types.Goal], forUniqueGoalId: Types.UniqueId): Bool {
      let goal = Array.find<Types.Goal>(
        goalsSearchSet, 
        func(t: Types.Goal): Bool { t.id == forUniqueGoalId }
      );
      switch (goal) {
        case (?goal) { true };
        case (_) { false };
      };
    };

    // for stable state
    public func getEntries(): [(Types.UniqueId, [Types.Goal])] { Iter.toArray(userIdToGoalsMap_.entries()) };
    
    public func getCountOfAllGoals(): Nat { 
      var count: Nat = 0;
      for (goals in userIdToGoalsMap_.vals()) { count += goals.size(); };
      return count;
    };

    // assertive call to allocate :[goal] for given userid
    public func initializeNewUserGoals(forUniqueUserId: Types.UniqueId): () {
      assert(not userIdMaps_(forUniqueUserId));
      userIdToGoalsMap_.put(forUniqueUserId, []);
    };

    // assertive call 
    public func getSpecificUserGoals(forUniqueUserId: Types.UniqueId): [Types.Goal] {
      assert(userIdMaps_(forUniqueUserId));
      let exists = userIdToGoalsMap_.get(forUniqueUserId);
      switch (exists) {
        case (null) { Prelude.unreachable(); };
        case (?exists) { return exists };
      };
    };

    // assertive call
    public func getSpecificUserTotalGoalCount(forUniqueUserId: Types.UniqueId): Nat {
      assert(userIdMaps_(forUniqueUserId));
      return getSpecificUserGoals(forUniqueUserId).size();
    };

    // assertive call but will assert fail if user id does not have goals created at all
    public func getSpecificUserGoal(forUniqueUserId: Types.UniqueId, forUniqueGoalId: Types.UniqueId): Result.Result<Types.Goal, Text> {
      assert(userIdMaps_(forUniqueUserId));
      let goal = Array.find<Types.Goal>(
        getSpecificUserGoals(forUniqueUserId), 
        func(t: Types.Goal): Bool { t.id == forUniqueGoalId }
      );
      switch (goal) {
        case (?goal) { #ok(goal) };
        case (_) { #err(Errors.GoalNotFound)};
      };
    };

    public func editGoalMetadataOrContent(
      forUniqueUserId: Types.UniqueId,
      forUniqueGoalId: Types.UniqueId,
      titleIn: ?Text,
      contentIn: ?Text,
      tagsIn: ?[Text],
    ): Result.Result<Types.Goal, Text> {
      assert(userIdMaps_(forUniqueUserId));
      let userGoals = getSpecificUserGoals(forUniqueUserId);
      assert(goalIdExistsInGoalSet_(userGoals, forUniqueGoalId));
      userIdToGoalsMap_.put(
        forUniqueUserId, 
        editGoalDetails_(
          userGoals, 
          forUniqueGoalId, titleIn, contentIn, tagsIn, null
        )
      );
      return getSpecificUserGoal(forUniqueUserId, forUniqueGoalId);
    }; 

    // generic add function, note traps if invalid data is passed as error checking done prior to this being called
    func addGoal_( 
      forUniqueUserId: Types.UniqueId,
      newGoalId: Types.UniqueId,
      titleIn: ?Text,
      contentIn: ?Text,
      tagsIn: ?[Text],
      scheduledStatusIn: Types.ScheduledStatus,
    ): Result.Result<Types.Goal, Text> {
      assert(userIdMaps_(forUniqueUserId));
      switch (scheduledStatusIn) {
        case (#completed args) { assert(true); };
        case (#scheduled (start, stop)) { assert(start < stop) }; // error is returned on incoming call, so can safely explicitly trap here
        case (#active (start, optNomInterval)) { assert(not Option.isSome(optNomInterval)); };
        case (#unscheduled) {  };
      }; 
      // reverse order unwrapped: (cause this is totally not confusing)
      // get existing goals
      // add new unscheduled goal to this list
      // pass the returned list with the new goal to the edit goal function
      // pass the returned list now containing a new goal whose fields have been set to the map 

      // alternatively the immutable array of goals could be retrieved, thawed, edited, frozen and stored back in the map
      // was going for "functional"
      userIdToGoalsMap_.put(forUniqueUserId, 
        editGoalDetails_(
          addNewUnscheduledNonSpecificGoal_(
            getSpecificUserGoals(forUniqueUserId), newGoalId), 
            newGoalId, titleIn, contentIn, tagsIn, ?scheduledStatusIn
        )
      );
      return getSpecificUserGoal(forUniqueUserId, newGoalId);
    }; 

    public func addNewUnscheduledGoal(
      forUniqueUserId: Types.UniqueId,
      newGoalId: Types.UniqueId,
      titleIn: ?Text,
      contentIn: ?Text,
      tagsIn: ?[Text],
    ): Result.Result<Types.Goal, Text>  {
      return addGoal_(forUniqueUserId, newGoalId, titleIn, contentIn, tagsIn, #unscheduled);
    };

    public func addNewScheduledGoal(
      forUniqueUserId: Types.UniqueId,
      newGoalId: Types.UniqueId,
      titleIn: ?Text,
      contentIn: ?Text,
      tagsIn: ?[Text],
      nominalStartTimeIn: Time.Time,
      nominalStopTimeIn: Time.Time
    ): Result.Result<Types.Goal, Text>  {
      if (nominalStartTimeIn > nominalStopTimeIn) {
        return #err(Errors.InvalidScheduleTimes);
      };
      return addGoal_(forUniqueUserId, newGoalId, titleIn, contentIn, tagsIn, (#scheduled(nominalStartTimeIn, nominalStopTimeIn)));
    };

    public func addNewActiveGoal(
      forUniqueUserId: Types.UniqueId,
      newGoalId: Types.UniqueId,
      titleIn: ?Text,
      contentIn: ?Text,
      tagsIn: ?[Text],
    ): Result.Result<Types.Goal, Text> {
      return addGoal_(forUniqueUserId, newGoalId, titleIn, contentIn, tagsIn, (#active(Time.now(), null)));
    };

    // turn an unscheduled goal into a scheduled goal 
    public func scheduleUnscheduledGoal(
      forUniqueUserId: Types.UniqueId,
      forUniqueGoalId: Types.UniqueId,
      nominalStartTimeIn: Time.Time, // becomes nominal
      nominalStopTimeIn: Time.Time   // becomes nominal
    ): Result.Result<Types.Goal, Text> {
      if (nominalStartTimeIn > nominalStopTimeIn) {
        return #err(Errors.InvalidScheduleTimes);
      };
      assert(userIdMaps_(forUniqueUserId));
      let goal = Array.find<Types.Goal>(
        getSpecificUserGoals(forUniqueUserId), 
        func(t: Types.Goal): Bool { t.id == forUniqueGoalId }
      );
      switch (goal) {
        case (null) { assert(false); }; // verify it existed
        case (?goal) { 
          switch (goal.currentScheduledStatus) {
            case (#unscheduled) { }; // only unscheduled -> scheduled
            case (_) { assert(false); };
          };
        };
      };
      let allGoals = getSpecificUserGoals(forUniqueUserId);
      let updatedGoals = editGoalDetails_(
        allGoals, forUniqueGoalId, null, null, null, 
        ?(#scheduled(nominalStartTimeIn, nominalStopTimeIn))); 
      userIdToGoalsMap_.put(forUniqueUserId, updatedGoals);
      return getSpecificUserGoal(forUniqueUserId, forUniqueGoalId);
    }; 

    public func rescheduleScheduledGoal(
      forUniqueUserId: Types.UniqueId,
      forUniqueGoalId: Types.UniqueId,
      nominalStartTimeIn: Time.Time, // becomes nominal
      nominalStopTimeIn: Time.Time   // becomes nominal
    ): Result.Result<Types.Goal, Text> {
      if (nominalStartTimeIn > nominalStopTimeIn) {
        return #err(Errors.InvalidScheduleTimes);
      };
      assert(userIdMaps_(forUniqueUserId));
      let userGoals = getSpecificUserGoals(forUniqueUserId);
      let goal = Array.find<Types.Goal>(userGoals, 
        func(t: Types.Goal): Bool { t.id == forUniqueGoalId }
      );
      switch (goal) {
        case (null) { assert(false); }; // verify it existed
        case (?goal) { 
          switch (goal.currentScheduledStatus) {
            case (#scheduled(nominal)) { }; // only rescheduled means only scheduled -> scheduled
            case (_) { assert(false); };
          };
        };
      };
      let allGoals = getSpecificUserGoals(forUniqueUserId);
      let updatedGoals = editGoalDetails_(
        allGoals, forUniqueGoalId, null, null, null, 
        ?(#scheduled(nominalStartTimeIn, nominalStopTimeIn))); 
      userIdToGoalsMap_.put(forUniqueUserId, updatedGoals);
      return getSpecificUserGoal(forUniqueUserId, forUniqueGoalId);
    }; 

    // can only be scheduled, for "bumping" in case an active goal completes after another one was scheduled to be active
    public func unscheduleScheduledGoal(
      forUniqueUserId: Types.UniqueId,
      forUniqueGoalId: Types.UniqueId,
    ): Result.Result<Types.Goal, Text> {
      assert(userIdMaps_(forUniqueUserId));
      let userGoals = getSpecificUserGoals(forUniqueUserId);
      let goal = Array.find<Types.Goal>(userGoals, 
        func(t: Types.Goal): Bool { t.id == forUniqueGoalId }
      );
      switch (goal) {
        case (null) { assert(false); }; // verify it existed
        case (?goal) { 
          switch (goal.currentScheduledStatus) {
            case (#scheduled(nominal)) { }; // verify it was scheduled
            case (_) { assert(false); };
          };
        };
      };
      let allGoals = getSpecificUserGoals(forUniqueUserId);
      let updatedGoals = editGoalDetails_(
        allGoals, forUniqueGoalId, null, null, null, 
        ?(#unscheduled)); 
      userIdToGoalsMap_.put(forUniqueUserId, updatedGoals);
      return getSpecificUserGoal(forUniqueUserId, forUniqueGoalId);
    }; 

    // can be either scheduled or unscheduled
    public func activateExistingGoal(
      forUniqueUserId: Types.UniqueId,
      forUniqueGoalId: Types.UniqueId,
    ): Result.Result<Types.Goal, Text> {
      assert(userIdMaps_(forUniqueUserId));
      let userGoals = getSpecificUserGoals(forUniqueUserId);
      let goal = Array.find<Types.Goal>(userGoals, 
        func(t: Types.Goal): Bool { t.id == forUniqueGoalId }
      );
      var schedule: Types.ScheduledStatus = #unscheduled;
      switch (goal) {
        case (null) { assert(false); }; // verify it existed
        case (?goal) { 
          switch (goal.currentScheduledStatus) {
            case (#unscheduled) { schedule := (#active(Time.now(), null)); };
            // should a user be able to activate a previousily scheduled goal, ie, !realStartTime < nominalStartTime?
            case (#scheduled(nominal)) { schedule := (#active(Time.now(), ?nominal)); };  
            case (_) { assert(false); }; // active/complete fails
          };
        };
      };
      assert(not (schedule == #unscheduled));

      let allGoals = getSpecificUserGoals(forUniqueUserId);

      let updatedGoals = editGoalDetails_(
        allGoals, forUniqueGoalId, null, null, null, 
        ?(schedule)); 

      userIdToGoalsMap_.put(forUniqueUserId, updatedGoals);
      return getSpecificUserGoal(forUniqueUserId, forUniqueGoalId);
    }; 
 
    // can only be active
    public func completeActiveGoal(
      forUniqueUserId: Types.UniqueId,
      forUniqueGoalId: Types.UniqueId,
    ): Result.Result<Types.Goal, Text>  {
      assert(userIdMaps_(forUniqueUserId));
      let userGoals = getSpecificUserGoals(forUniqueUserId);
      let goal = Array.find<Types.Goal>(userGoals, 
        func(t: Types.Goal): Bool { t.id == forUniqueGoalId }
      );
      var schedule: Types.ScheduledStatus = #unscheduled;
      switch (goal) {
        case (null) { assert(false); }; // verify it existed
        case (?goal) { 
          switch (goal.currentScheduledStatus) {
            case (#active(realStartTime, optNominalInterval)) {
              assert(realStartTime < Time.now()); 
              schedule := #completed((realStartTime, Time.now()), optNominalInterval); 
            };
            case (_) { assert(false); }; // only active goals can be completed
          };
        };
      };
      // no need to assert schedule == active

      let allGoals = getSpecificUserGoals(forUniqueUserId);

      let updatedGoals = editGoalDetails_(
        allGoals, forUniqueGoalId, null, null, null, 
        ?(schedule)); 

      userIdToGoalsMap_.put(forUniqueUserId, updatedGoals);
      return getSpecificUserGoal(forUniqueUserId, forUniqueGoalId);
    }; 

    public func removeExistingGoal(
      forUniqueUserId: Types.UniqueId,
      forUniqueGoalId: Types.UniqueId,
    ): Result.Result<(Text, Types.UniqueId), Text>  {
      assert(userIdMaps_(forUniqueUserId));
      let userGoals = getSpecificUserGoals(forUniqueUserId);
      let goal = Array.find<Types.Goal>(userGoals, 
        func(t: Types.Goal): Bool { t.id == forUniqueGoalId }
      );
      var schedule: Types.ScheduledStatus = #unscheduled;
      switch (goal) {
        case (null) { assert(false); }; // verify it existed
        case (?goal) { };
      };
      let updatedGoals = deleteGoal_(userGoals, forUniqueGoalId); 
      userIdToGoalsMap_.put(forUniqueUserId, updatedGoals);
      return #ok("Successfully removed goal", forUniqueGoalId);
    }; 

    // generic function that simply returns array with new non-specific goal added
    func addNewUnscheduledNonSpecificGoal_(
      existingGoals: [Types.Goal],
      newGoalId: Types.UniqueId,
    ): [Types.Goal] {
      let goals: Buffer.Buffer<Types.Goal> = Constants.toFilledBuffer(existingGoals);
      goals.add({
        id = newGoalId;
        epochCreationTime = Time.now();
        epochLastUpdateTime = Time.now();
        title = "unnamed goal #" # newGoalId;
        content = "unspecified default content";
        tags = [];
        currentScheduledStatus = #unscheduled;
      });
      return goals.toArray();
    };

    // generic function that overwrites any existing values if new values are present
    func editGoalDetails_(
      existingGoals: [Types.Goal],
      targetGoalId: Types.UniqueId,
      titleIn: ?Text,
      contentIn: ?Text,
      tagsIn: ?[Text],
      scheduledStatusIn: ?Types.ScheduledStatus,
    ): [Types.Goal] {
      var throwError: Bool = true;
      let updateFcn = func(goal: Types.Goal): Types.Goal {
        if (goal.id == targetGoalId) {
          throwError := false;
          return {
            id = targetGoalId;
            epochCreationTime = goal.epochCreationTime;
            epochLastUpdateTime = Time.now();
            title = Option.get<Text>(titleIn, goal.title);
            content = Option.get<Text>(contentIn, goal.content);
            tags = Option.get<[Text]>(tagsIn, goal.tags);
            currentScheduledStatus = Option.get<Types.ScheduledStatus>(scheduledStatusIn, goal.currentScheduledStatus);
          };
        } else { goal };
      };
      let updated = Array.map<Types.Goal, Types.Goal>(existingGoals, updateFcn);
      assert(not throwError);
      return updated;
    };
  };

     // generic function that drops goal if present
    func deleteGoal_(existingGoals: [Types.Goal], targetGoalId: Types.UniqueId): [Types.Goal] {
      var throwError: Bool = true;
      let filterFcn = func(goal: Types.Goal): Bool {
        if (targetGoalId == goal.id) {
          throwError := false;
          return false;
        } else { return true; };
      };
      let updated = Array.filter<Types.Goal>(existingGoals, filterFcn);
      assert(not throwError);
      return updated;
    };
}