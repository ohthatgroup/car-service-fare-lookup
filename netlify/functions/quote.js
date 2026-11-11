"use strict";
/* Share landing page: carries the quote's Open Graph tags (preview image =
   the amount) and sends people straight into the app at that quote. */
function esc(s){
  return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;")
    .replace(/>/g, "&gt;").replace(/"/g, "&quot;");
}

exports.handler = async (event) => {
  const q = event.queryStringParameters || {};
  const host = event.headers.host || "stupendous-pastelito-af88a7.netlify.app";
  const origin = "https://" + host;

  const route = q.gf
    ? q.gf + " zone fare"
    : (q.f || "") + " → " + (q.t || "");
  const amount = String(q.a || "").slice(0, 24);
  const title = (route + (amount ? " — " + amount : "")).trim() || "Car Service Fare Lookup";
  const ogImg = origin + "/ogimg?a=" + encodeURIComponent(amount || "Fare Lookup") +
    "&r=" + encodeURIComponent(route);

  // App deep link: pass the quote params through (drop the display amount).
  const app = new URLSearchParams();
  for(const k of ["f", "t", "trip", "mv", "ap", "gf", "gr", "gc"]) if(q[k]) app.set(k, q[k]);
  const appUrl = origin + "/?" + app.toString();

  const html = "<!DOCTYPE html><html lang=\"en\"><head><meta charset=\"utf-8\">" +
    "<title>" + esc(title) + "</title>" +
    "<meta property=\"og:type\" content=\"website\">" +
    "<meta property=\"og:title\" content=\"" + esc(title) + "\">" +
    "<meta property=\"og:description\" content=\"Car service fare — tap to open the live quote.\">" +
    "<meta property=\"og:image\" content=\"" + esc(ogImg) + "\">" +
    "<meta property=\"og:image:width\" content=\"1200\">" +
    "<meta property=\"og:image:height\" content=\"630\">" +
    "<meta name=\"twitter:card\" content=\"summary_large_image\">" +
    "<meta http-equiv=\"refresh\" content=\"0;url=" + esc(appUrl) + "\">" +
    "</head><body style=\"font-family:-apple-system,sans-serif;text-align:center;padding:40px\">" +
    "<p>" + esc(title) + "</p>" +
    "<p><a href=\"" + esc(appUrl) + "\">Open the quote</a></p>" +
    "<script>location.replace(" + JSON.stringify(appUrl) + ");</script>" +
    "</body></html>";

  return {
    statusCode: 200,
    headers: { "Content-Type": "text/html; charset=utf-8", "Cache-Control": "public, max-age=300" },
    body: html
  };
};
