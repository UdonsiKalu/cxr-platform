import { ApolloServer } from "@apollo/server";
import { startStandaloneServer } from "@apollo/server/standalone";
import { buildSubgraphSchema } from "@apollo/subgraph";
import { parse } from "graphql";

const typeDefs = parse(/* GraphQL */ `
  extend schema
    @link(url: "https://specs.apollo.dev/federation/v2.0", import: ["@key"])

  type Policy {
    id: ID!
    claimId: ID!
    code: String!
    description: String
  }

  type Query {
    policies: [Policy!]!
    policyForClaim(claimId: ID!): Policy
  }
`);

const policies = [
  {
    id: "pol-1",
    claimId: "demo-1",
    code: "CXR-POL-OK",
    description: "Claim meets bootcamp policy stub",
  },
  {
    id: "pol-2",
    claimId: "demo-2",
    code: "CXR-POL-REVIEW",
    description: "Manual review required",
  },
];

const resolvers = {
  Query: {
    policies: () => policies,
    policyForClaim: (_parent, { claimId }) =>
      policies.find((p) => p.claimId === claimId) ?? null,
  },
};

const server = new ApolloServer({
  schema: buildSubgraphSchema({ typeDefs, resolvers }),
});

const port = Number(process.env.PORT || 4002);
const { url } = await startStandaloneServer(server, { listen: { port } });
console.log(`policies subgraph ready at ${url}`);
