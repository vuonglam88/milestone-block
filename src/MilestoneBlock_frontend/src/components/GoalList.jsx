import React, { useContext, useState } from 'react';
import styled from 'styled-components'

import { GoalContext } from "./GoalContextProvider";

import GoalCard from './GoalCard';
import LoadingIndicator from "./LoadingIndicator";
import ConfirmError from './ConfirmError';

const GoalList = () => {

    const {
        goals,
        isLoading,
        isUpdating,
        hasError,
        clearError,
        deleteGoal,
        updateGoalStatus,
        editGoal
    } = useContext(GoalContext);

    return (
        <SContainer>
        { isLoading ? 
            <LoadingIndicator />
            :
            <>
            { (isUpdating || hasError) ?
                <ListOverlay>
                    { isUpdating ? <LoadingIndicator displayText={isUpdating ? "updating" : "loading"} /> : null }
                    { hasError ? <ConfirmError errorMessage={hasError} onConfirmed={() => clearError()} /> : null }
                </ListOverlay>
                : null
            }
            { goals.length > 0 ? 
                <ListContainer blur={isUpdating || hasError }>
                    { goals.map((goal) => (
                        <GoalCard 
                            key={goal.id} 
                            {...goal}
                            updateGoalStatus={updateGoalStatus} 
                            editGoal={editGoal}
                            deleteGoal={deleteGoal}
                        />
                    ))}
                </ListContainer>
                :
                <>
                <SNoGoals>There are no milestones to display</SNoGoals>
                </>
            }
            </>
        }
        </SContainer>
    )
}

const SContainer = styled.div`
    position: relative;
    display: flex;
    flex-direction: column;
    margin: 2rem 2rem;
`

const ListOverlay = styled.div`
    position: absolute;
    width: 100%;
    height: 100%;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    z-index: 90;
`

const SNoGoals = styled.div`
    display: flex;
    align-items: center;
    justify-content: center;
    margin-top: 20%;
`

const ListContainer = styled.div`
    z-index: 1;
    filter: ${props => props.blur ? "blur(.1em)" : null }
`




export default GoalList;