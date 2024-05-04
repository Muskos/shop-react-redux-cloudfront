import { AzureFunction, Context } from "@azure/functions";
import { getProductTotal } from "../services/products";

const httpTrigger: AzureFunction = async function (
  context: Context
): Promise<void> {
  context.log("HTTP get total products processed a request.");
  const total = await getProductTotal();

  context.res = {
    body: total,
  };
};

export default httpTrigger;
