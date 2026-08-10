import { createDeleteAccountHandler } from "./handler.ts";
import { createLiveDependencies } from "./live_dependencies.ts";

Deno.serve(createDeleteAccountHandler(createLiveDependencies()));
