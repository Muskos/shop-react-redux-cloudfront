import { AzureFunction, Context, HttpRequest } from "@azure/functions";
import { getProduct } from "../services/products";

const httpTrigger: AzureFunction = async function (
  context: Context,
  req: HttpRequest
): Promise<void> {
  context.log("HTTP get product by id processed a request.");

  if (req.params && req.params.productId) {
    const product = await getProduct(req.params.productId);

    context.res = {
      body: product,
    };
  } else {
    context.res = {
      status: 404,
    };
  }
};

export default httpTrigger;
