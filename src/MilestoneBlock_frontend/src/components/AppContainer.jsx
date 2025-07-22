import React, { createContext } from "react";
import { Outlet, useNavigate } from "react-router-dom";

import { useConnect } from "@connect2ic/react";

import AppNavigation from "./AppNavigation";
import GoalContextProvider from "./GoalContextProvider";

const AppContext = createContext();

const AppContainer = () => {
  const navigate = useNavigate();

  const { isConnected, principal, activeProvider } = useConnect({
    onConnect: () => {
      navigate("/home");
    },
    onDisconnect: () => {
      navigate("/");
    },
  });

  const appContext = {
    isConnected,
  };

  return (
    <div className="full-width-height">
      <AppContext.Provider value={appContext}>
        <GoalContextProvider isConnected={isConnected} principal={principal}>
          <AppNavigation />
          <Outlet />
        </GoalContextProvider>
      </AppContext.Provider>
    </div>
  );
};

export { AppContext };

export default AppContainer;
