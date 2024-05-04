import { AzureFunction, Context, HttpRequest } from "@azure/functions";

const httpTrigger: AzureFunction = async function (
  context: Context,
  req: HttpRequest
): Promise<void> {
  // TODO see u next time
  if (req.params && req.params.productId) {
    context.log(req.params.productId);
    context.res = {
      body: {
        id: req.params.productId,
        title: "PGP1",
        description: "Desc1",
        price: 100,
      },
    };
  } else {
    context.res = {
      body: {
        id: req.params.productId,
        title: "PGP1",
        description: "Desc1",
        price: 100,
      },
    };
  }
};

export default httpTrigger;
