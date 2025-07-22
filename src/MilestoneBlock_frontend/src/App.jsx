import React from "react";
import AppRouter from "./components/AppRouter";
import { defaultProviders } from "@connect2ic/core/providers";
import { createClient } from "@connect2ic/core";
import { Connect2ICProvider } from "@connect2ic/react";
import "@connect2ic/core/style.css";

import { InternetIdentity } from "@connect2ic/core/providers/internet-identity";
import * as main from "../../declarations/MilestoneBlock_backend";

BigInt.prototype.toJSON = function () {
  return this.toString();
};

const isDev = process.env.DFX_NETWORK === "local";

const App = () => {
  return <AppRouter />;
};

const getProviders = () => {
  return isDev
    ? [
        new InternetIdentity({
          dev: true,
          whitelist: [],
          providerUrl: `http://${process.env.CANISTER_ID_INTERNET_IDENTITY}.localhost:4943`,
          host: window.location.origin,
        }),
      ]
    : defaultProviders;
};

const client = createClient({
  canisters: {
    main,
  },
  providers: getProviders(),
  globalProviderConfig: {
    dev: isDev,
  },
});

export default () => (
  <Connect2ICProvider client={client}>
    <App />
  </Connect2ICProvider>
);
