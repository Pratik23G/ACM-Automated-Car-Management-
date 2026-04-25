import { app } from "./app.js";
import { env } from "./config/env.js";
import { logger } from "./config/logger.js";

app.listen(env.PORT, () => {
  logger.info(`ACM2 backend listening on port ${env.PORT}`);
});
