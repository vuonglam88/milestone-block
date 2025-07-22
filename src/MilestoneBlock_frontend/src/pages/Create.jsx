import React from "react";
import styled from "styled-components";

import CreateGoal from "../components/CreateGoal";

const Create = () => {
    return (
        <SConainter>
            <CreateGoal />
        </SConainter>
    )
}

const SConainter = styled.div`
    width: 90%;
    margin: 1rem auto;
    padding: 2rem;
`

export default Create;