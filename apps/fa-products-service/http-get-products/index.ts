import { AzureFunction, Context } from "@azure/functions";
import products from "./products.json";

type Product = {
  id: string;
  title: string;
  description: string;
  price: number;
};

const httpTrigger: AzureFunction = async function (
  context: Context
): Promise<void> {
  context.log("HTTP trigger function processed a request.");

  context.res = {
    body: products,
  };
};

export default httpTrigger;
