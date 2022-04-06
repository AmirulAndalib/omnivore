/* eslint-disable @typescript-eslint/no-unsafe-call */
/* eslint-disable @typescript-eslint/restrict-template-expressions */
/* eslint-disable @typescript-eslint/no-unsafe-return */
/* eslint-disable @typescript-eslint/no-unsafe-member-access */
/* eslint-disable @typescript-eslint/no-unsafe-assignment */
/* eslint-disable @typescript-eslint/require-await */
import { ContextFunction } from 'apollo-server-core'
import { Claims, ClaimsToSet, ResolverContext } from './resolvers/types'
import { SetClaimsRole } from './utils/dictionary'
import Knex, { Transaction } from 'knex'
import { ExpressContext } from 'apollo-server-express/dist/ApolloServer'
import * as jwt from 'jsonwebtoken'
import { kx } from './datalayer/knex_config'
import { tracer } from './tracing'
import { env } from './env'
import { promisify } from 'util'
import { buildLogger } from './utils/logger'
import { ApolloServer } from 'apollo-server-express'
import { makeExecutableSchema } from '@graphql-tools/schema'
import typeDefs from './schema'
import { sanitizeDirectiveTransformer } from './directives'
import { functionResolvers } from './resolvers/function_resolvers'
import ScalarResolvers from './scalars'
import * as Sentry from '@sentry/node'
import { createPubSubClient } from './datalayer/pubsub'
import { initModels } from './server'

const signToken = promisify(jwt.sign)
const logger = buildLogger('app.dispatch')
const pubsub = createPubSubClient()

const resolvers = {
  ...functionResolvers,
  ...ScalarResolvers,
}

const contextFunc: ContextFunction<ExpressContext, ResolverContext> = async ({
  req,
  res,
}) => {
  let claims: Claims | undefined

  const token = req?.cookies?.auth || req?.headers?.authorization

  logger.info(`handling gql request`, {
    query: req.body.query,
    variables: req.body.variables,
  })

  if (token && jwt.verify(token, env.server.jwtSecret)) {
    claims = jwt.decode(token) as Claims
  }

  async function setClaims(
    tx: Transaction,
    uuid?: string,
    userRole?: string
  ): Promise<void> {
    const uid =
      (claims && claims.uid) || uuid || '00000000-0000-0000-0000-000000000000'
    const dbRole =
      userRole === SetClaimsRole.ADMIN ? 'omnivore_admin' : 'omnivore_user'
    return tx.raw('SELECT * from omnivore.set_claims(?, ?)', [uid, dbRole])
  }

  const ctx = {
    log: logger,
    claims,
    kx,
    pubsub,
    // no caching for subscriptions
    // TODO: create per request caching for connections
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    models: initModels(kx, true),
    clearAuth: () => {
      res.clearCookie('auth')
      res.clearCookie('pendingUserAuth')
    },
    signToken,
    setAuth: async (
      claims: ClaimsToSet,
      secret: string = env.server.jwtSecret
    ) => {
      const token = await signToken(claims, secret)

      res.cookie('auth', token, {
        httpOnly: true,
        expires: new Date(new Date().getTime() + 365 * 24 * 60 * 60 * 1000),
      })
    },
    setClaims,
    authTrx: <TResult>(
      cb: (tx: Knex.Transaction) => TResult,
      userRole?: string
    ): Promise<TResult> =>
      kx.transaction(async (tx) => {
        await setClaims(tx, undefined, userRole)
        return cb(tx)
      }),
    tracingSpan: tracer.startSpan('apollo.request'),
  }

  return ctx
}

export function makeApolloServer(): ApolloServer {
  let schema = makeExecutableSchema({
    resolvers,
    typeDefs,
  })

  schema = sanitizeDirectiveTransformer(schema)

  const apollo = new ApolloServer({
    schema: schema,
    context: contextFunc,
    formatError: (err) => {
      Sentry.captureException(err)
      // hide error messages from frontend on prod
      console.log('error', err)
      return new Error('Unexpected server error')
    },
  })

  return apollo
}
