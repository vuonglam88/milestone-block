
const callCanisterQueryAllGoalsOfUser = async ({ canister }) => {
    return await canister.queryAllGoalsOfUser();
}

export default callCanisterQueryAllGoalsOfUser;