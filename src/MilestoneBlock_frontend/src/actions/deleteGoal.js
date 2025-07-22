

const callCanisterDeleteGoal = async ({ canister, goalId }) => {
    return await canister.removeExistingGoal({ goalIdIn: goalId });
}

export default callCanisterDeleteGoal;