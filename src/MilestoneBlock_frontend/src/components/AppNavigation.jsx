import React, { useContext, useState } from "react";
import { Link, NavLink } from "react-router-dom";
import styled from "styled-components";

import { AppContext } from "./AppContainer";

import { ConnectButton, ConnectDialog } from "@connect2ic/react";

const AppNavigation = () => {
  const { isConnected } = useContext(AppContext);

  return (
    <>
      <SNavigation>
        <SLink to="/">MilestoneBlock</SLink>
        <div className="flex-one" />
        <ConnectButton />
      </SNavigation>
      <SNavigation>
        {isConnected ? (
          <>
            <SNavLink to="/create">Create</SNavLink>
            <div className="unit-square" />
            <SNavLink to="/home">Home</SNavLink>
            <div className="unit-square" />
            <SNavLink to="/profile">Profile</SNavLink>
            <div className="unit-square" />
          </>
        ) : null}
      </SNavigation>
      <ConnectDialog />
    </>
  );
};

const SNavigation = styled.nav`
  display: flex;
  flex-direction: row;
  align-items: center;
  padding: 0 2rem;
  margin-top: 1rem;
`;

// used for the current selected nav link
const SNavLink = styled(NavLink)`
  text-decoration: none;
  color: black;
  padding: 0.25rem 2rem;
  border: 1px solid black;

  &:visited {
    background-color: white;
    color: black;
  }
  &.active {
    color: white;
    background-color: black;
  }
  &:hover {
    color: white;
    background-color: grey;
  }
`;

// used for the index link, to link back to the root / ie landing page
const SLink = styled(Link)`
  text-decoration: none;
  color: black;
  font-size: 2em;
  text-shadow: 1px 2px 3px hsla(240, 60%, 30%, 0.5);

  &:visited {
    background-color: white;
    color: black;
  }
  &.active {
    color: black;
    background-color: white;
  }
`;

export default AppNavigation;
