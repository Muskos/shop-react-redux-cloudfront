import { AzureFunction, Context, HttpRequest } from "@azure/functions";
import { createProduct } from "../services/products";

const httpTrigger: AzureFunction = async function (
  context: Context,
  req: HttpRequest
): Promise<void> {
  context.log("HTTP post product processed a request.");
  if (
    req.body &&
    req.body.title &&
    req.body.description &&
    req.body.count !== undefined &&
    req.body.price
  ) {
    await createProduct({
      title: req.body.title,
      description: req.body.description,
      price: req.body.price,
      count: req.body.count,
      id: req.body.id,
    });
  } else {
    context.res = {
      status: 400,
    };
  }
};

export default httpTrigger;
