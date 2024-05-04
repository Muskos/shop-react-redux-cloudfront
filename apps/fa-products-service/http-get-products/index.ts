import { AzureFunction, Context } from "@azure/functions";
import { getProducts } from "../services/products";

const httpTrigger: AzureFunction = async function (
  context: Context
): Promise<void> {
  context.log("HTTP get product processed a request.");

  const products = await getProducts();

  context.res = {
    body: products,
  };
};

export default httpTrigger;
