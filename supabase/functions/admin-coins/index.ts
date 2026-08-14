import { createAdminCoinsHandler } from "./handler.ts";
import { createLiveDependencies } from "./live_dependencies.ts";

Deno.serve(createAdminCoinsHandler(createLiveDependencies()));
