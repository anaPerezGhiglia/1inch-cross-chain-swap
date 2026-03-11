import { defineConfig } from "hardhat/config";

// Shared compiler settings for default and lite profiles
const baseCompilerSettings = {
  optimizer: {
    enabled: true, // Forge default: true (Hardhat default: false)
    runs: 1_000_000,
  },
  evmVersion: "shanghai" as const,
  viaIR: true,
};

export default defineConfig({
  solidity: {
    profiles: {
      default: {
        compilers: [
          {
            version: "0.8.23",
            settings: baseCompilerSettings,
          },
        ],
      },
      lite: {
        compilers: [
          {
            version: "0.8.23",
            settings: {
              ...baseCompilerSettings,
              optimizer: {
                ...baseCompilerSettings.optimizer,
                details: {
                  yulDetails: {
                    optimizerSteps: "",
                  },
                },
              },
            },
          },
        ],
      },
      // [profile.zksync] — zkSync-specific profile; no Hardhat 3 equivalent (requires zkSync toolchain)
    },
  },
  paths: {
    sources: "./contracts", // Forge default: "src"; this project uses "contracts"
    tests: "./test",
  },
  test: {
    solidity: {
      fuzz: {
        runs: 1024, // foundry.toml [fuzz] runs = 1024
      },
      fsPermissions: {
        readFile: ["./examples/config/config.json"],
        readDirectory: ["./broadcast", "./reports", "./config"],
      },
    },
  },
  // TODO: gas_reports — no Hardhat equivalent for forge test --gas-report target filtering
  // TODO: forge snapshot — not supported. See: https://github.com/NomicFoundation/hardhat/issues/7769
  // TODO: forge doc — Foundry-only; community plugin @solarity/hardhat-markup is an alternative
  // Foundry-only settings not migrated:
  // - out = "out" — Hardhat uses artifacts/ + cache/
  // - libs = ["lib"] — Hardhat resolves via remappings.txt and Node.js resolution
  // - [fmt] — forge fmt is standalone; prettier-plugin-solidity is an alternative
});
