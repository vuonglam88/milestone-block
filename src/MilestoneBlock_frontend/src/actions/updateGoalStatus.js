const callCanisterUpdateGoalStatus = async ({ canister, goalId, newStatus, scheduledInterval, previousStatus }) => {
    switch (newStatus) {
        case 'Scheduled':
            if (scheduledInterval) {
                if (previousStatus === 'Scheduled') {
                    //'reschedule_scheduled';
                    return await canister.rescheduleScheduledGoal({ 
                        goalIdIn: goalId,
                        newScheduledStartTime: scheduledInterval[0].getTime() * 1000000,
                        newScheduledStopTime: scheduledInterval[1].getTime() * 1000000
                    });
                } else if (previousStatus === 'Unscheduled') {
                    //'schedule_unscheduled';
                    return await canister.scheduledUnscheduledGoal({ 
                        goalIdIn: goalId,
                        scheduledStartTime: scheduledInterval[0].getTime() * 1000000,
                        scheduledStopTime: scheduledInterval[1].getTime() * 1000000
                    });
                } else {
                    throw new Error("Tried to rescheduled goal without correct args " + JSON.stringify({ newStatus, previousStatus }));
                }
            } else { 
                throw new Error("Tried to rescheduled goal without correct new scheduled interval"  + JSON.stringify({ newStatus, previousStatus, scheduledInterval }));
            }
        case 'Complete':
             // 'complete_active';
            return await canister.completeActiveGoal({ goalIdIn: goalId });
        case 'Active':
            // 'activate_existing';
            return await canister.activateScheduledOrUnscheduledGoal({ goalIdIn: goalId });
        case 'Unscheduled':
            // 'unscheduled_scheduled'
            return await canister.unscheduleScheduledGoal({ goalIdIn: goalId });
        default:
            throw new Error("Tried to rescheduled goal without correct args - fell to default case");
    }
}

export default callCanisterUpdateGoalStatus;
