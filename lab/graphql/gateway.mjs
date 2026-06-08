import { ApolloServer } from "@apollo/server";
import { startStandaloneServer } from "@apollo/server/standalone";
import { ApolloGateway, IntrospectAndCompose } from "@apollo/gateway";

const claimsUrl =
  process.env.CLAIMS_SUBGRAPH_URL || "http://127.0.0.1:4001/graphql";
const policiesUrl =
  process.env.POLICIES_SUBGRAPH_URL || "http://127.0.0.1:4002/graphql";

const gateway = new ApolloGateway({
  supergraphSdl: new IntrospectAndCompose({
    subgraphs: [
      { name: "claims", url: claimsUrl },
      { name: "policies", url: policiesUrl },
    ],
    pollIntervalInMs: 30000,
  }),
});

const server = new ApolloServer({ gateway });
const port = Number(process.env.PORT || 4000);
const { url } = await startStandaloneServer(server, { listen: { port } });
console.log(`Apollo gateway ready at ${url}`);
console.log(`  claims subgraph:   ${claimsUrl}`);
console.log(`  policies subgraph: ${policiesUrl}`);
