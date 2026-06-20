import Foundation

/// Version of the public `ph` scripting contract documented in
/// `docs/cli-contract.md`. Bump this string in lockstep with that document
/// when the JSON shape, exit-code mapping, identifier precedence, or
/// stdout/stderr policy changes in a way that is not strictly additive.
///
/// Stays a plain `String` rather than an `enum` so downstream tools that
/// shell out to `ph` can compare without importing the library.
public let PromptHubCLISchemaVersion: String = "1"

/// Release version of the `ph` binary, surfaced by `ph --version`.
///
/// This is the SemVer that release artifacts are tagged with (`ph-vX.Y.Z`)
/// and MUST stay in lockstep with `Formula/ph.rb`'s `STABLE_VERSION`.
/// It is distinct from `PromptHubCLISchemaVersion`, which versions the
/// JSON/exit-code contract rather than the build.
///
/// When cutting a release, bump this constant in the same change that bumps
/// `STABLE_VERSION` in the formula. See `docs/cli-release.md`.
public let PromptHubCLIVersion: String = "0.1.0"
