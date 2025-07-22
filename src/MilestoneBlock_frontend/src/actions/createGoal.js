
const callCanisterCreateGoal = async ({ canister, statusType, title, description, tags, scheduledInterval }) => {
    const methodSignatureArgumentFormat = {
        titleIn: [ title ],
        contentIn: [ description ], 
        tagsIn: [ tags ]
    }
    switch (statusType) {
        case 'Unscheduled':
            return await canister.addNewUnscheduledGoal({ ...methodSignatureArgumentFormat });
        case 'Scheduled':
            const [ start, stop ] = scheduledInterval;
            methodSignatureArgumentFormat.scheduledStartTime = start * 1000000;
            methodSignatureArgumentFormat.scheduledStopTime = stop * 1000000;
            return await canister.addNewScheduledGoal({ ...methodSignatureArgumentFormat });
        case 'Active':
            return await canister.addNewActiveGoal({ ...methodSignatureArgumentFormat });
        default:
            throw new Error("Tried to create goal without valid status");
    }
}

export default callCanisterCreateGoal;

