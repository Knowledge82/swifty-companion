/// 42 API host (without the scheme). The `https` scheme is added when the
/// address is built.
const String apiHost = 'api.intra.42.fr';

/// 42 API version, the first path segment (`/v2/...`). This is the current
/// version according to the official guide
/// (https://api.intra.42.fr/apidoc/guides). The token is requested separately,
/// at `/oauth/token`, which has no version.
const String apiVersion = 'v2';

/// Hosts the app token may be sent to together with a photo request. The photo
/// address comes from the server response, so it must not be trusted blindly:
/// otherwise a forged foreign address would receive our token.
const Set<String> photoHosts = {'cdn.intra.42.fr'};
