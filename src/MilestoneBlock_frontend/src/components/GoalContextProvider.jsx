import React, { createContext, useContext } from "react";

import { AppContext } from "./AppContainer";

import { useCanister } from "@connect2ic/react";
import useCanisterGoals from "../hooks/useCanisterGoals";

const GoalContext = createContext();

const GoalContextProvider = ({ children, isConnected, principal }) => {
  const [canister] = useCanister("main");

  return (
    <GoalContext.Provider
      value={useCanisterGoals(isConnected, principal, canister)}
    >
      {children}
    </GoalContext.Provider>
  );
};

export { GoalContext };
export default GoalContextProvider;
