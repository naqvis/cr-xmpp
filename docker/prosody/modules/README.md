# Prosody integration-test modules

These modules are vendored only for the Docker interoperability test server.
They are not runtime dependencies of `cr-xmpp`.

- `mod_sasl2.lua`: `mod_sasl2` 37-1, source revision `aaf92bf929e5`
- `mod_sasl2_bind2.lua`: `mod_sasl2_bind2` 19-1, source revision `86989059de5b`

Both modules come from the
[Prosody community modules repository](https://hg.prosody.im/prosody-modules/)
and are distributed under the MIT/X11 license.
