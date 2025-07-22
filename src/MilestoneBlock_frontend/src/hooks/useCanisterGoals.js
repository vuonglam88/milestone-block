import { useState, useEffect } from 'react';

import callCanisterCreateGoal from '../actions/createGoal';
import callCanisterUpdateGoalStatus from '../actions/updateGoalStatus';
import callCanisterEditGoal from '../actions/editGoal';
import callCanisterQueryAllGoalsOfUser from '../actions/queryGoals';
import callCanisterDeleteGoal from '../actions/deleteGoal';
import goalViewModelTransform from '../actions/viewModelTransforms';

// custom hook for doing CRUD operations on goals in canister
// note while some methods (such as delete) are simple, all the
// actions have been abstracted and can be found in /actions
// also note the useEffect queries all the goals when the
// user authenticates (is in the dependency array) which
// could also be cached in localstorage/indexdb in the future
// final note: probably can combine error/createError, contrived
// for the sake of using React router to show create as its own page
// a better ui would probably have create and updates done in a modal,
// thereby limiting the scope of what the user is exposed to to the
// context of their user interaction

const useCanisterGoals = (isConnected, principal, canister) => {
 
    // note the useCanister hook provides 2 state variables (result error), however I manually handle them
    // here to learn how to expect results from canisters
 
    const [ goals, setGoals ] = useState([]);
    const [ isLoading, setLoading ] = useState(false);
    const [ isUpdating, setUpdating ] = useState(false);
    const [ hasError, setError ] = useState(false);
    const [ hasCreateError, setCreateError ] = useState(false);

    const clearError = () => { setError(false); setCreateError(false); }

    const createGoal = async (goalDetails, callback) => {
        setUpdating(true);
        setCreateError(false);
        let error = false;
        try {
            let response = await callCanisterCreateGoal({ canister, ...goalDetails });
            if (response.ok) {
                updateList(response.ok.id, goalViewModelTransform(response.ok), true) 
            } else {
                setCreateError(response.err);
                error = true;
            }
        } catch (error) {
            console.error("Caught error trying to create new goal: " + error);
        } finally {
            setUpdating(false);
            if (!error) {
                callback();
            }
        }
    }

    const editGoal = async (goalId, field, newValue) => {
        setUpdating(true);
        setError(false);
        try {
            let response = await callCanisterEditGoal({ canister, goalId, field, newValue });
            response.ok ? 
                updateList(response.ok.id, goalViewModelTransform(response.ok)) 
                : 
                setError(response.err);
        } catch (error) {
            console.error("Caught error while trying to edit goal details: " + error.message)
        } finally {
            setUpdating(false);
        }
    }

    const updateGoalStatus = async (goalId, newStatus, scheduledInterval, previousStatus) => {
        setUpdating(true);
        setError(false);
        try {
            let response = await callCanisterUpdateGoalStatus({ canister, goalId, newStatus, scheduledInterval, previousStatus });
            response.ok ? 
                updateList(response.ok.id, goalViewModelTransform(response.ok)) 
                : 
                setError(response.err);
        } catch (error) {
            console.error("Caught error while trying to update goal status: " + error)
        } finally {
            setUpdating(false);
        }
    }

    const deleteGoal = async (goalId) => {
        setUpdating(true);
        setError(false);
        try {
            let response = await callCanisterDeleteGoal({ canister, goalId });
            response.ok ? updateList(goalId) : setError(response.err);
        } catch (error) {
            console.error("Caught error while trying to delete goal with id: " + error)
        } finally {
            setUpdating(false);
        }
    }

    // convience method to update goals used as state
    const updateList = (goalId, updatedGoal, wasCreated) => {
        let updatedGoals;
        if (updatedGoal) {
            if (wasCreated) {
                // goal was created, update the state adding the new goal
                updatedGoals = [...goals, updatedGoal ];
            } else {
                // goal was updated, update the state to reflect the changes
                updatedGoals = goals.map((goal) => goal.id === goalId ? { ...updatedGoal } : goal );
            }
        } else {
            // goal was deleted, update state to remove deleted goal
            updatedGoals = goals.filter((goal) => goal.id !== goalId);
        }
        setGoals(updatedGoals);
    }

    // loads the goals from a query made to the canister on component mount 
    // or if the refreshTrigger in dep array changes (ie, if updating feed oninterval)
    useEffect(() => {
        if (!isConnected || principal === '2vxsx-fae') return;
        let mounted = true;
        const query = async () => {
            try {
                setLoading(true);
                setUpdating(false);
                setError(false);
                await canister.authenticateWithUserAccountCreationIfNecessary();
                let response = await callCanisterQueryAllGoalsOfUser({ canister });
                if (mounted) {
                    response.ok ? setGoals(response.ok.map(goalViewModelTransform)) : setError(response.err);
                }
            } catch (error) {
                console.error("Caught error while querying canister for goal list: " + error)
            } finally {
                if (mounted) setLoading(false);
            }
        }
        if (isConnected && principal !== '2vxsx-fae') {
            query();
        }
        // prevents memory leaks if the componented is unmounted and call unfinished
        return () => mounted = false;

    // note, here we could add a new goal in the same way goals of the list are updated
    // by adding a method create goal, however for the sake of learning react useEffect dependency array and router
    // (ie a "better" design would likely use the create and update flows in a modal)
    }, [ isConnected, principal, canister ])

    return {
        goals,
        isLoading,
        isUpdating,
        hasError,
        hasCreateError,
        clearError,
        createGoal,
        deleteGoal,
        updateGoalStatus,
        editGoal
    }
}

export default useCanisterGoals;

