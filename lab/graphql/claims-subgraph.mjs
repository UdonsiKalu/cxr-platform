import { ApolloServer } from "@apollo/server";
import { startStandaloneServer } from "@apollo/server/standalone";
import { buildSubgraphSchema } from "@apollo/subgraph";
import { parse } from "graphql";

const typeDefs = parse(/* GraphQL */ `
  extend schema
    @link(url: "https://specs.apollo.dev/federation/v2.0", import: ["@key"])

  """CXR-shaped claim (matches bootcamp fixtures / Kafka events)."""
  type Claim @key(fields: "id") {
    id: ID!
    status: String!
    summary: String
  }

  type Query {
    claim(id: ID!): Claim
    claims: [Claim!]!
  }
`);

const claims = [
  { id: "demo-1", status: "ok", summary: "SW.15 GraphQL lab — analyzed claim" },
  { id: "demo-2", status: "review", summary: "Pending policy check" },
];

const resolvers = {
  Query: {
    claim: (_parent, { id }) => claims.find((c) => c.id === id) ?? null,
    claims: () => claims,
  },
  Claim: {
    __resolveReference(ref) {
      return claims.find((c) => c.id === ref.id) ?? null;
    },
  },
};

const server = new ApolloServer({
  schema: buildSubgraphSchema({ typeDefs, resolvers }),
});

const port = Number(process.env.PORT || 4001);
const { url } = await startStandaloneServer(server, { listen: { port } });
console.log(`claims subgraph ready at ${url}`);
