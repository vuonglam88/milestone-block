import Time "mo:base/Time";

module {

  // defining a class of types will simplify the rest of the code, and also make it easier to share in the event
  // the canister should have other canister's come a'calling

  // this should be replaced by uuid or ulid see aviate labs https://github.com/aviate-labs/ulid.mo
  public type UniqueId = Text;

  public type UserMetadata = {
    epochCreationTime: Time.Time;
    epochLastUpdateTime: Time.Time;
    monotonicCreateGoalCount: Nat;
    preferredDisplayName: Text;
    emailAddress: Text;
    associatedPrincipal: Text;
  };

  public type Goal = {
    id: UniqueId;
    epochCreationTime: Time.Time;
    epochLastUpdateTime: Time.Time;
    title: Text;
    content: Text;
    tags: [Text];
    currentScheduledStatus: ScheduledStatus;
  };

  public type StartTime = Time.Time;
  public type StopTime = Time.Time;
  public type Interval = (StartTime, StopTime);
  public type NominalInterval = Interval; // "nominal" means "scheduled as assigned with specific start and stop time"

    //                                          Goal "Life-Cycle"
    //               +-> active 
    //                     -> complete (only)
    // <user intent> +-> scheduled 
    //                      -> active or -> xunscheduled (if bumped) or -> (re)scheduled
    //               +-> unscheduled
    //                      -> scheduled or -> active 

    // thus, every goal that is completed has at least a real stop time assigned when it is completed. it's real start time
    // is assigned when it is activated. if it was scheduled before it was activated, it will also have a nominal start and
    // stop time; if wasn't (it was unscheduled then activated, or created as an active goal) it will only have the real
    // start and stop time. 
  public type ScheduledStatus = {
    #unscheduled;
    #scheduled: NominalInterval;
    #active: (StartTime, ?NominalInterval); // if activated goal was prevousily scheduled -> NominalInterval
    #completed: (Interval, ?NominalInterval); // "Real"Interval, if was previousily scheduled -> NominalInterval
  }; 

  public type PIdContextStableState = [(Principal, UniqueId)];
  public type UsersMetadataStableState = [(UniqueId, UserMetadata)];
  public type UsersGoalsStableState = [(UniqueId, [Goal])];
};
