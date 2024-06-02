import { AzureFunction, Context } from "@azure/functions";
import { createProduct } from "../services/products";

const serviceBusTopicTrigger: AzureFunction = async function (
  context: Context,
  message
): Promise<void> {
  context.log(
    "Service Bus trigger function to add product processed a request."
  );
  context.log("PRODUCT:", message, context.bindings.message);

  const product = await createProduct(message);

  context.res = {
    body: product,
  };
};

export default serviceBusTopicTrigger;
