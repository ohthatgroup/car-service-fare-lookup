"use strict";
/* Share links.
   Short form: /s/<fareId>[r][m][p]  (r=round trip, m=mini van, p=airport pickup)
               /s/g<baseIdx>-<rowIdx>-<colIdx>  for zone-grid quotes.
   The fare is resolved from the database here, so the link stays tiny and
   the preview image shows the real amount. Legacy /q?f=..&t=..&a=.. links
   keep working. Either way the page carries the Open Graph tags and sends
   people into the app at that quote. */
const SB = "https://axmamofelrnewhbtkwlu.supabase.co";
const KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF4bWFtb2ZlbHJuZXdoYnRrd2x1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTQzNjY3MzIsImV4cCI6MjEwOTk0MjczMn0.k7eq_pGtEsC9I7nv5AWQ9lk1AhsfmbxH4jrAMXXdsH4";

function esc(s){
  return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;")
    .replace(/>/g, "&gt;").replace(/"/g, "&quot;");
}
async function db(path){
  const r = await fetch(SB + "/rest/v1/" + path, {
    headers: { "apikey": KEY, "Authorization": "Bearer " + KEY }
  });
  if(!r.ok) return null;
  return r.json();
}
function plainPrice(p){
  if(p == null) return null;
  const s = String(p).replace(/[$,]/g, "").trim();
  if(!/^[\d.]+$/.test(s)) return null;
  const n = parseFloat(s);
  return isNaN(n) ? null : n;
}
function money(n){
  return "$" + (Number.isInteger(n) ? String(n) : n.toFixed(2));
}
function miniVanAddition(oneWay, rules){
  if(oneWay == null || !rules || !rules.minivan_brackets) return null;
  for(const pair of rules.minivan_brackets){
    if(oneWay <= pair[0]) return pair[1];
  }
  return null;
}

/* Returns { route, amount, appParams } for a short code, or null. */
async function resolveCode(code){
  const grid = code.match(/^g(\d+)-(\d+)-(\d+)$/);
  if(grid){
    const cells = await db("grid_cells?select=base,row_index,row_label,col_index,col_label,price&order=base.asc,row_index.asc,col_index.asc");
    if(!cells) return null;
    const bases = [...new Set(cells.map(c => c.base))].sort();
    const base = bases[Number(grid[1])];
    const cell = cells.find(c => c.base === base && c.row_index === Number(grid[2]) && c.col_index === Number(grid[3]));
    if(!cell) return null;
    const rulesRows = await db("base_rules?select=grid_label&base=eq." + encodeURIComponent(base));
    const label = (rulesRows && rulesRows[0] && rulesRows[0].grid_label) || (base + " zone fare");
    return {
      route: base + " → " + label,
      amount: cell.price,
      appParams: { gf: base, gr: cell.row_label, gc: cell.col_label }
    };
  }
  const m = code.match(/^(\d+)([rmp]*)$/);
  if(!m) return null;
  const rows = await db("fares?select=id,from_place,category,to_place,price,round_trip&id=eq." + m[1]);
  if(!rows || !rows.length) return null;
  const fare = rows[0];
  const flags = m[2];
  const round = flags.includes("r") && !!fare.round_trip;
  const rulesRows = await db("base_rules?select=airport_pickup_fee,minivan_brackets&base=eq." + encodeURIComponent(fare.from_place));
  const rules = rulesRows && rulesRows[0];
  const oneWay = plainPrice(fare.price);
  const rtVal = fare.round_trip ? plainPrice(fare.round_trip) : null;
  let total = null, printed = fare.price;
  if(round && rtVal != null){ total = rtVal; printed = fare.round_trip; }
  else if(!round && oneWay != null){ total = oneWay; }
  else if(round){ printed = fare.round_trip; }
  if(total != null){
    if(flags.includes("p") && rules && rules.airport_pickup_fee != null) total += Number(rules.airport_pickup_fee);
    if(flags.includes("m")){
      const add = miniVanAddition(oneWay, rules);
      if(add != null) total += add;
    }
  }
  const appParams = { f: fare.from_place, t: fare.to_place };
  if(round) appParams.trip = "round";
  if(flags.includes("m")) appParams.mv = "1";
  if(flags.includes("p")) appParams.ap = "1";
  return {
    route: fare.from_place + " → " + fare.to_place,
    amount: total != null ? money(total) : printed,
    appParams
  };
}

module.exports = async (req, res) => {
  const q = req.query || {};
  const host = req.headers.host || "fare-lookup.vercel.app";
  const origin = "https://" + host;

  let route = "", amount = "", appParams = null;
  if(q.code){
    try {
      const res2 = await resolveCode(String(q.code));
      if(res2){ route = res2.route; amount = String(res2.amount || ""); appParams = res2.appParams; }
    } catch(e){ /* fall through to a generic page */ }
  }
  if(!appParams){
    route = q.gf ? q.gf + " zone fare" : (q.f || "") + " → " + (q.t || "");
    amount = String(q.a || "").slice(0, 24);
    appParams = {};
    for(const k of ["f", "t", "trip", "mv", "ap", "gf", "gr", "gc"]) if(q[k]) appParams[k] = q[k];
  }

  const title = (route + (amount ? " — " + amount : "")).trim() || "Car Service Fare Lookup";
  const ogImg = origin + "/ogimg?a=" + encodeURIComponent(amount || "Fare Lookup") +
    "&r=" + encodeURIComponent(route);
  const appUrl = origin + "/?" + new URLSearchParams(appParams).toString();

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

  res.setHeader("Content-Type", "text/html; charset=utf-8");
  res.setHeader("Cache-Control", "public, max-age=300");
  res.status(200).send(html);
};
