import { FiatTokenV2Instance } from "../../../@types/generated";
import { testTransferWithAuthorization } from "./testTransferWithAuthorization";
import { testApproveWithAuthorization } from "./testApproveWithAuthorization";
import { testCancelAuthorization } from "./testCancelAuthorization";
import { TestParams } from "./helpers";

export function hasGasAbstraction(
  getFiatToken: () => FiatTokenV2Instance,
  getDomainSeparator: () => string,
  fiatTokenOwner: string,
  accounts: Truffle.Accounts
): void {
  describe("GasAbstraction", () => {
    const testParams: TestParams = {
      getFiatToken,
      getDomainSeparator,
      fiatTokenOwner,
      accounts,
    };

    testTransferWithAuthorization(testParams);
    testApproveWithAuthorization(testParams);
    testCancelAuthorization(testParams);
  });
}
