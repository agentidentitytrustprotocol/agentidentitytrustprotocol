> **Non-normative.** This page describes how AITP can sit next to the Model Context Protocol (MCP). It defines no wire format, no requirement and no conformance fixture. Where it touches a rule, it points at the RFC that states it; if this page and an RFC disagree, the RFC wins.

# AITP and MCP

MCP connects an AI application (the MCP client) to a server that exposes tools, resources and prompts. Over HTTP, MCP protects that server with OAuth 2.1. AITP does not change that. It adds a second, separate statement: which agent is on the other end, which keys and identity types that agent accepts, and what that agent has granted the caller.

This page covers four things:

1. how an MCP client presents a TCT to an MCP server;
2. how the TCT `aud` claim relates to the OAuth `resource` parameter of RFC 8707;
3. where RFC 9728 protected-resource metadata could point at the AITP Manifest;
4. what AITP does not replace.

---

## The MCP baseline used here

This page was checked against the **MCP specification, revision 2026-07-28**, the latest dated revision at the time of writing (the specification's `latest` URL resolves to it). The primary sources are:

- Authorization: <https://modelcontextprotocol.io/specification/2026-07-28/basic/authorization>
- Authorization server discovery: <https://modelcontextprotocol.io/specification/2026-07-28/basic/authorization/authorization-server-discovery>
- Authorization security considerations: <https://modelcontextprotocol.io/specification/2026-07-28/basic/authorization/security-considerations>
- Streamable HTTP transport: <https://modelcontextprotocol.io/specification/2026-07-28/basic/transports/streamable-http>
- Key changes since 2025-11-25: <https://modelcontextprotocol.io/specification/2026-07-28/changelog>

The OAuth documents cited are [RFC 8707](https://www.rfc-editor.org/rfc/rfc8707.html) (Resource Indicators for OAuth 2.0) and [RFC 9728](https://datatracker.ietf.org/doc/html/rfc9728) (OAuth 2.0 Protected Resource Metadata).

The MCP facts this page relies on, all from that revision:

- Authorization is optional in MCP. It applies to HTTP-based transports. A server on the stdio transport takes credentials from its environment instead. Everything on this page is about the Streamable HTTP transport.
- A protected MCP server is an OAuth 2.1 resource server. The MCP client is an OAuth 2.1 client. An authorization server issues the access token.
- The client sends the access token as `Authorization: Bearer <access-token>` on every HTTP request.
- The client sends the RFC 8707 `resource` parameter, set to the MCP server's canonical URI, in both the authorization request and the token request. The server checks that a token was issued for it.
- The server publishes RFC 9728 protected-resource metadata, found through the `resource_metadata` parameter of a `401` `WWW-Authenticate` challenge or at a well-known URI. The metadata names at least one authorization server.
- Token passthrough is forbidden: the server accepts only tokens issued for it, and does not forward a token it received to an upstream API.
- Revision 2026-07-28 removed protocol-level sessions and the `initialize` handshake. Each request stands alone and carries its own metadata.

The last point matters for AITP. There is no MCP session in which a peer's identity could be established once, so a TCT is presented on each request, as an access token is.

---

## Roles

| AITP | MCP | OAuth 2.1 |
|---|---|---|
| Initiating peer (holds the TCT) | MCP client | OAuth client |
| Target peer (issues the TCT, publishes the Manifest) | MCP server | Resource server |
| none | none | Authorization server |

In this mapping the MCP server is a full AITP peer. It publishes a Manifest ([RFC-AITP-0003](../rfcs/RFC-AITP-0003-manifest.md)) and answers the Mutual Handshake ([RFC-AITP-0004](../rfcs/RFC-AITP-0004-mutual-handshake.md)). The MCP client is a full AITP peer too, with its own AID. The OAuth authorization server has no AITP role.

---

## 1. Presenting a TCT to an MCP server

### Getting the TCT

Before its first MCP request, the client fetches and verifies the server's Manifest ([RFC-AITP-0003 §5](../rfcs/RFC-AITP-0003-manifest.md#5-manifest-verification)) and runs the Mutual Handshake against the Manifest's `handshake_endpoint`. The handshake is an AITP exchange, not an MCP request. The TCT the server issues arrives in `MUTUAL_COMMIT_ACK` ([RFC-AITP-0004 §3.4](../rfcs/RFC-AITP-0004-mutual-handshake.md#34-mutual_commit_ack)). Its `iss` is the server's AID, and its `sub` and `aud` are the client's AID ([RFC-AITP-0005 §2](../rfcs/RFC-AITP-0005-tct.md#2-claims)).

### Carriage

The carriage is the one RFC-AITP-0014 already uses for A2A. The client sends the TCT, as the compact JWS string with no further encoding, in the `x-aitp-tct` request header. See [RFC-AITP-0014 §5.1](../rfcs/RFC-AITP-0014-a2a-agent-card.md#51-request-headers) for the header rules, and [`registries/media-types.md`](../registries/media-types.md) for the media type. For MCP, the A2A-specific parts of that section (the `A2A-Extensions` header) do not apply.

The access token and the TCT travel side by side on the same request:

```http
POST /mcp HTTP/1.1
Host: mcp.example.com
Content-Type: application/json
Accept: application/json, text/event-stream
MCP-Protocol-Version: 2026-07-28
Mcp-Method: tools/call
Mcp-Name: summarize
Authorization: Bearer eyJhbGciOiJSUzI1NiIs…
x-aitp-tct: eyJhbGciOiJFZERTQSIsInR5cCI6ImFpdHAtdGN0K2p3dCJ9.eyJ2ZXIiOiJhaXRwLzAuMyIs…

{ "jsonrpc": "2.0", "id": 7, "method": "tools/call", "params": { "name": "summarize", "arguments": { "doc": "arXiv:2401.00001" } } }
```

The JSON-RPC body is abbreviated: a 2026-07-28 request also carries its protocol version and client capabilities in `params._meta`. The `x-aitp-tct` header does not take the place of `Authorization`, and the TCT is never sent as a bearer token. A TCT is bound to the client's key (`cnf.jkt`, [RFC-AITP-0005 §3](../rfcs/RFC-AITP-0005-tct.md#3-confirmation-claim-cnf)). [RFC-AITP-0014 §10](../rfcs/RFC-AITP-0014-a2a-agent-card.md#10-alternatives-considered) explains why the `Authorization` header is left to OAuth.

### Proof of possession

The downstream PoP exchange is defined in [RFC-AITP-0005 §6.1](../rfcs/RFC-AITP-0005-tct.md#61-downstream-pop-exchange) and [§6.2](../rfcs/RFC-AITP-0005-tct.md#62-verification). Over HTTP it rides in the `x-aitp-pop-challenge` response header and the `x-aitp-pop-response` request header, as [RFC-AITP-0005 §6.3](../rfcs/RFC-AITP-0005-tct.md#63-where-this-exchange-happens) names them. [RFC-AITP-0014 §5.3](../rfcs/RFC-AITP-0014-a2a-agent-card.md#53-downstream-pop-on-a2a) shows the same exchange step by step for A2A; an MCP deployment can follow it unchanged.

One MCP-specific point. That exchange starts with a `401` response. An MCP client reads a `401` as the start of OAuth discovery. A client that speaks both checks for `x-aitp-pop-challenge` first. If it is present, the client answers the challenge and retries the request with the same access token. It starts no new OAuth flow.

### What the server checks

The server receives back a TCT it issued. So the check is made from the issuer's side: `iss` is the server's own AID, `aud` (equal to `sub`) names the client presenting the token, and the client proves it holds the `sub` key by PoP or channel binding. The server takes the expected audience from that proof, never from the token. [RFC-AITP-0005 §10.5](../rfcs/RFC-AITP-0005-tct.md#105-issuer-as-resource-server) defines this check for every transport, so an MCP server follows it directly. [RFC-AITP-0014 §5.2](../rfcs/RFC-AITP-0014-a2a-agent-card.md#52-server-verification) cites it for A2A.

The audience rule of [RFC-AITP-0005 §5.2](../rfcs/RFC-AITP-0005-tct.md#52-audience-validation), "`aud` matches its own AID", is the holder-side mode. It does not apply to a server verifying a TCT it issued.

After the TCT checks, the server authorizes the call against the TCT's `grants` ([RFC-AITP-0005 §4](../rfcs/RFC-AITP-0005-tct.md#4-grants)). Which grant a tool, resource or prompt needs is the server's own mapping. AITP does not standardize it.

### MCP's single-token wording

The MCP authorization text speaks of one token per request. It says a server accepts only tokens valid for its own resources, and accepts or transits no other tokens. That text is aimed at token passthrough: an MCP server that accepts, or forwards, an access token issued for some other resource.

A TCT presented to the server that issued it is not that case. It is not an OAuth access token, it is issued for presentation back to its issuer, and the server forwards it nowhere. Still, the MCP specification does not describe a second credential next to the access token. An operator who adds `x-aitp-tct` adds something MCP does not itself define.

---

## 2. TCT `aud` and the RFC 8707 `resource` parameter

The two audiences name different things.

| | OAuth access token (MCP) | AITP TCT |
|---|---|---|
| Who issues it | The authorization server | The MCP server itself, in the Mutual Handshake |
| Audience | The MCP server, named by its canonical URI through the `resource` parameter ([RFC 8707 §2](https://www.rfc-editor.org/rfc/rfc8707.html#section-2)) | The client: `aud` equals `sub`, the holder's AID ([RFC-AITP-0005 §5.1](../rfcs/RFC-AITP-0005-tct.md#51-format)) |
| Form of the audience | An absolute URI | An AID, `aid:<method>:<identifier>`; never a URL, never an array |
| How it is tied to the server | The server checks it is the token's audience | The server checks it is the token's issuer (`iss`), then checks PoP for `sub` ([RFC-AITP-0005 §10.5](../rfcs/RFC-AITP-0005-tct.md#105-issuer-as-resource-server)) |

So `aud` and `resource` do not map onto each other, and neither is derived from the other:

- A client does not put the MCP server's canonical URI, or its AID, in a TCT. It cannot: the server mints the TCT.
- A client does not send its own AID, or the server's AID, as the `resource` parameter. `resource` stays the MCP server's canonical URI, as MCP describes.
- The authorization server never sees the TCT, and the TCT never names the authorization server.

The two values do meet in one place: the URL the client calls. The OAuth side ties that URL to the token through `resource`. The AITP side has no equivalent for MCP yet. For A2A, RFC-AITP-0014 makes the server list its endpoint URLs in its signed Manifest, and the client checks the URL it calls against that list ([RFC-AITP-0014 §4.1](../rfcs/RFC-AITP-0014-a2a-agent-card.md#41-the-a2a-interfaces-manifest-key), [§4.2](../rfcs/RFC-AITP-0014-a2a-agent-card.md#42-client-verification-order) step 5). That check is what stops card shadowing ([RFC-AITP-0014 §9.2](../rfcs/RFC-AITP-0014-a2a-agent-card.md#92-card-shadowing)). No Manifest extension key lists MCP endpoints today ([extension-key registry](../registries/extension-keys.md)). If one is defined later, the MCP canonical URI is the natural value to list, since it is already the string both sides of the OAuth flow agree on.

---

## 3. Pointing from RFC 9728 metadata to the Manifest

### Where the Manifest is found today

The Manifest already has a home: `https://<agent-host>/.well-known/aitp-manifest` ([RFC-AITP-0003 §4](../rfcs/RFC-AITP-0003-manifest.md#4-well-known-endpoint)). An MCP client that knows the server's host can fetch it there with no help from OAuth metadata. [docs/discovery.md](discovery.md) lists other ways a client learns where to look.

### A pointer in protected-resource metadata

An MCP client already fetches the server's protected-resource metadata to find the authorization server. RFC 9728 allows additional metadata parameters ([RFC 9728 §2](https://datatracker.ietf.org/doc/html/rfc9728#section-2)), and a client ignores parameters it does not understand ([RFC 9728 §3.2](https://datatracker.ietf.org/doc/html/rfc9728#section-3.2)). So the same document could also carry the Manifest URL:

```json
{
  "resource": "https://mcp.example.com/mcp",
  "authorization_servers": ["https://auth.example.com"],
  "scopes_supported": ["files:read"],
  "aitp_manifest": "https://mcp.example.com/.well-known/aitp-manifest"
}
```

`aitp_manifest` here is an illustration only. It is not in the IANA "OAuth Protected Resource Metadata" registry ([RFC 9728 §8.1](https://datatracker.ietf.org/doc/html/rfc9728#section-8.1)), and no AITP RFC defines it. A real parameter would need a registration and a spec.

### The metadata is a pointer, not a trust root

Protected-resource metadata is an unauthenticated document, apart from TLS. A Manifest URL found in it is an untrusted pointer, in the same way an A2A Agent Card is ([RFC-AITP-0014 §4.2](../rfcs/RFC-AITP-0014-a2a-agent-card.md#42-client-verification-order) step 1):

- The client verifies the Manifest itself ([RFC-AITP-0003 §5](../rfcs/RFC-AITP-0003-manifest.md#5-manifest-verification)), whatever pointed to it.
- The client takes the server's AID, accepted identity types, trust anchors, offered capabilities and handshake endpoint from the verified Manifest, never from the metadata. This mirrors [RFC-AITP-0014 §4.3](../rfcs/RFC-AITP-0014-a2a-agent-card.md#43-effective-values-come-from-the-manifest).
- A client that pins the server's AID by configuration checks the Manifest against the pin.
- RFC 9728 signed metadata (`signed_metadata`, [RFC 9728 §2.2](https://datatracker.ietf.org/doc/html/rfc9728#section-2.2)) does not change this. It is a JWT signed by the party its `iss` claim names, and RFC 9728 does not tie that party's key to the AID. The reasoning is the same as for A2A Card signatures ([RFC-AITP-0014 §4.4](../rfcs/RFC-AITP-0014-a2a-agent-card.md#44-agent-card-signatures)).

The pointer saves a client one guess about where the Manifest lives. It adds no trust.

---

## 4. What AITP does not replace

**OAuth 2.1 remains MCP's authorization mechanism.** Everything MCP's authorization specification describes stays as it is: protected-resource metadata, authorization server discovery, client registration, PKCE, the `resource` parameter, scopes, step-up authorization, and the bearer access token on every request. An MCP server that adds AITP still validates the access token exactly as MCP describes.

AITP adds context next to it:

| Question | Answered by |
|---|---|
| Is this request authorized on behalf of the resource owner (usually a user)? | OAuth: the access token and its scopes |
| Which agent sent it, proven by key? | AITP: the TCT's `sub`, plus PoP |
| What has this server agreed that agent may do? | AITP: the TCT's `grants` |
| Which identity types and trust anchors does the server accept from agents? | AITP: the verified Manifest |

The two checks are independent. Each has to pass on its own. A request with a valid TCT and no valid access token fails MCP authorization. A request with a valid access token and no valid TCT fails the AITP check, if the server requires one. OAuth scopes and AITP grants are separate vocabularies: a server does not read one as the other, as [RFC-AITP-0014 §3.4](../rfcs/RFC-AITP-0014-a2a-agent-card.md#34-security-requirements) also says for A2A scopes.

AITP also does not:

- act as an OAuth authorization server, or issue access tokens;
- define a way to exchange a TCT for an access token, or the reverse. AITP `aitp/0.3` specifies neither DPoP nor OAuth 2.0 Token Exchange ([non-goals §13](non-goals.md#13-dpop-and-oauth-20-token-exchange));
- change MCP's message format, transports or `_meta` fields;
- apply to MCP's stdio transport, where MCP itself leaves authorization to the environment.

---

## Status and open items

- There is no MCP binding RFC. This page describes a pattern built from existing parts: the RFC-AITP-0014 header carriage, the RFC-AITP-0005 §6.3 PoP headers, and the RFC-AITP-0003 Manifest.
- The server-side check of a returned TCT is RFC-AITP-0005 §10.5. RFC-AITP-0005 is in Review, so that text can still change before Release Candidate.
- No Manifest extension key binds MCP endpoint URLs to the Manifest, and no RFC 9728 metadata parameter for the Manifest URL is registered.
- MCP revisions change. This page names the revision it was checked against. A later revision that changes authorization, transports or headers needs this page to be checked again.
