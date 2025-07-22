const callCanisterEditGoal = async ({ canister, goalId, field, newValue }) => {
    const params = { goalIdIn: goalId };
    // note the canister call is defined such that each value is optional, meaning
    // the UI could have been set so the goal is edited in batch, and each value if changed
    // is passed and added as a parameter instead of switching on a particular one
    // note we must pass in empty array for "null" opt type (ie, no value)

    params.titleIn = [];
    params.contentIn = [];
    params.tagsIn = [];
    switch (field) {
        case 'title':
            params.titleIn = [ newValue ];
            break;
        case 'description':
            params.contentIn = [ newValue ];
            break;
        case 'tags':
            params.tagsIn = [ newValue ];
            break;
        default:
            throw new Error("Invalid field for updating metadata tried to pass as param")
    }
    return await canister.updateSpecificGoalMetadataOrContent({ ...params });
}

export default callCanisterEditGoal;