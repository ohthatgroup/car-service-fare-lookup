"use strict";
/* Share links.
   Short form: /s/<fareId>[r][m][p]  (r=round trip, m=mini van, p=airport pickup)
               /s/g<baseIdx>-<rowIdx>-<colIdx>  for zone-grid quotes.
               /s/c<code>  for calculator fares — amount-only: the landing
               page SHOWS the amount big and the route, never rates or
               take-home, with an "Open FareLookup" button that deep-links
               to the quoted route (/?f=..&t=..&trip=..) — or the app home
               when the share has no route. (v4.2: the instant redirect
               to the fare sheet is gone — the recipient never saw the
               fare. The Open Graph tags are unchanged, so the WhatsApp
               preview still shows the amount.)
               /s/m<code>  for month snapshots (v4.4) — a point-in-time
               snapshot of one month (revenue, expenses, take-home,
               hours, recovered), frozen at share time; the landing
               page shows the numbers with the take-home big, and the
               WhatsApp preview shows the take-home. Stored as snap_*
               columns on the shares row.
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
/* v4.4: one price format everywhere — a raw DB string like "$85.00"
   becomes "$85"; a range or other unparseable price passes through. */
function printedMoney(s){ const n = plainPrice(s); return n != null ? money(n) : s; }
const MONTH_NAMES = ["January","February","March","April","May","June","July","August","September","October","November","December"];
function fmtMonth(ym){
  const m = /^(\d{4})-(\d{2})$/.exec(String(ym || ""));
  if(!m) return String(ym || "");
  return MONTH_NAMES[Number(m[2]) - 1] + " " + m[1];
}
function miniVanAddition(oneWay, rules, round){
  if(oneWay == null || !rules || !rules.minivan_brackets) return null;
  for(const pair of rules.minivan_brackets){
    if(oneWay <= pair[0]) return (round && pair.length > 2) ? pair[2] : pair[1];
  }
  return null;
}

/* Returns { route, amount, appParams } for a short code, or null. */

function trimNum(n){ return Number.isInteger(n) ? String(n) : String(Math.round(n * 100) / 100); }
function extrasOf(row){
  let add = 0; const parts = [];
  const wa = parseFloat(row.wait_amount);
  if(wa && wa > 0){
    if(row.wait_unit === "once"){ add += wa; parts.push("WAIT +$" + trimNum(wa)); }
    else {
      const hrs = Math.max(1, parseFloat(row.wait_hours) || 1);
      add += wa * hrs; parts.push("WAIT " + trimNum(hrs) + " HR $" + trimNum(wa * hrs));
    }
  }
  (row.addons || []).forEach(a => {
    const amt = parseFloat(a.amount);
    if(a.name && amt > 0){ add += amt; parts.push(String(a.name).toUpperCase() + " +$" + trimNum(amt)); }
  });
  return { add, parts };
}
async function resolveShare(code){
  const rows = await db("shares?code=eq." + encodeURIComponent(code) + "&select=*");
  const row = rows && rows[0];
  if(!row) return null;
  const ex = extrasOf(row);
  const custom = row.custom_price != null ? Number(row.custom_price) : null;
  const extras = ((custom != null ? ["CUSTOM $" + trimNum(custom)] : []).concat(ex.parts)).join(" · ");
  if(row.grid){
    const cells = await db("grid_cells?base=eq." + encodeURIComponent(row.grid.base) +
      "&row_index=eq." + row.grid.row + "&col_index=eq." + row.grid.col + "&select=price");
    const cell = cells && cells[0];
    const p = cell ? plainPrice(cell.price) : null;
    const base = custom != null ? custom : p;
    return { route: row.grid.base + " zone fare",
      amount: base != null ? money(base + ex.add) : (cell ? printedMoney(cell.price) : ""), extras,
      appParams: { sh: row.code } };
  }
  if(row.fare_id){
    const fares = await db("fares?select=id,from_place,category,to_place,price,round_trip&id=eq." + row.fare_id);
    const fare = fares && fares[0];
    if(!fare) return null;
    const rulesRows = await db("base_rules?select=airport_pickup_fee,minivan_brackets&base=eq." + encodeURIComponent(fare.from_place));
    const rules = rulesRows && rulesRows[0];
    const oneWay = plainPrice(fare.price);
    const round = row.trip === "round" && !!fare.round_trip;
    const rtVal = fare.round_trip ? plainPrice(fare.round_trip) : null;
    let total = null, printed = fare.price;
    if(round && rtVal != null){ total = custom != null ? custom : rtVal; printed = fare.round_trip; }
    else if(round && custom != null){ total = custom; printed = fare.round_trip; }
    else if(!round && oneWay != null){ total = custom != null ? custom : oneWay; }
    else if(!round && custom != null){ total = custom; }
    else if(round){ printed = fare.round_trip; }
    if(total != null){
      total += ex.add;
      if(row.airport && rules && rules.airport_pickup_fee != null) total += Number(rules.airport_pickup_fee);
      if(row.minivan){
        const add = miniVanAddition(!round && custom != null ? custom : oneWay, rules, round);
        if(add != null) total += add;
      }
    }
    return { route: fare.from_place + " → " + fare.to_place,
      amount: total != null ? money(total) : printedMoney(printed), extras,
      appParams: { sh: row.code } };
  }
  return null;
}

async function resolveCode(code){
  const calc = code.match(/^c([a-z0-9]{4,})$/i);
  if(calc){
    try {
      const rows = await db("shares?code=eq." + encodeURIComponent(calc[1]) + "&select=calc_fare,calc_route,calc_roundtrip");
      const row = rows && rows[0];
      if(row && row.calc_fare != null){
        /* v4.4: the Open button deep-links to the quoted route
           (/?f=..&t=..&trip=..) instead of the app home. */
        const params = {};
        if(row.calc_route){
          const parts = String(row.calc_route).split(" → ");
          if(parts.length === 2 && parts[0] && parts[1]){
            params.f = parts[0]; params.t = parts[1];
            if(row.calc_roundtrip) params.trip = "round";
          }
        }
        return { route: row.calc_route || "Calculator fare",
          amount: money(Number(row.calc_fare)),
          appParams: params, isCalc: true };
      }
    } catch(e){ return null; }
    return null;
  }
  /* v4.4: month snapshot shares — the landing page shows the frozen
     month's numbers; the preview shows the take-home. */
  const month = code.match(/^m([a-z0-9]{4,})$/i);
  if(month){
    try {
      const rows = await db("shares?code=eq." + encodeURIComponent(month[1]) + "&select=snap_month,snap_revenue,snap_expenses,snap_takehome,snap_hours,snap_recovered");
      const row = rows && rows[0];
      if(row && row.snap_month != null){
        return { route: fmtMonth(row.snap_month),
          amount: money(Number(row.snap_takehome)),
          appParams: {}, isMonth: true, snap: row };
      }
    } catch(e){ return null; }
    return null;
  }
  const shm = code.match(/^q([a-z0-9]{4,})$/i);
  if(shm){ try { return await resolveShare(shm[1]); } catch(e){ return null; } }
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
      amount: printedMoney(cell.price),
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
      const add = miniVanAddition(oneWay, rules, round);
      if(add != null) total += add;
    }
  }
  const appParams = { f: fare.from_place, t: fare.to_place };
  if(round) appParams.trip = "round";
  if(flags.includes("m")) appParams.mv = "1";
  if(flags.includes("p")) appParams.ap = "1";
  return {
    route: fare.from_place + " → " + fare.to_place,
    amount: total != null ? money(total) : printedMoney(printed),
    appParams
  };
}

module.exports = async (req, res) => {
  const q = req.query || {};
  const host = req.headers.host || "fare-lookup.vercel.app";
  const origin = "https://" + host;

  let route = "", amount = "", appParams = null, extrasTxt = "", isCalc = false, isMonth = false, snap = null;
  if(q.code){
    try {
      const res2 = await resolveCode(String(q.code));
      if(res2){ route = res2.route; amount = String(res2.amount || ""); appParams = res2.appParams; extrasTxt = res2.extras || ""; isCalc = !!res2.isCalc; isMonth = !!res2.isMonth; snap = res2.snap || null; }
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
    "&r=" + encodeURIComponent(route) + (extrasTxt ? "&x=" + encodeURIComponent(extrasTxt) : "");
  const appUrl = origin + "/?" + new URLSearchParams(appParams).toString();

  /* Calculator shares land ON the fare: amount big, route under it, one
     button to the quoted route (v4.4 — was the app home). No redirect,
     no rates, no take-home. */
  if(isCalc){
    const openUrl = (appParams && appParams.f && appParams.t) ? appUrl : origin + "/";
    const calcHtml = "<!DOCTYPE html><html lang=\"en\"><head><meta charset=\"utf-8\">" +
      "<title>" + esc(title) + "</title>" +
      "<meta property=\"og:type\" content=\"website\">" +
      "<meta property=\"og:title\" content=\"" + esc(title) + "\">" +
      "<meta property=\"og:description\" content=\"Car service fare — tap to open the live quote.\">" +
      "<meta property=\"og:image\" content=\"" + esc(ogImg) + "\">" +
      "<meta property=\"og:image:width\" content=\"1200\">" +
      "<meta property=\"og:image:height\" content=\"630\">" +
      "<meta name=\"twitter:card\" content=\"summary_large_image\">" +
      "</head><body style=\"font-family:-apple-system,sans-serif;text-align:center;padding:48px 20px;color:#111\">" +
      "<div style=\"font-size:17px;color:#666\">" + esc(route) + "</div>" +
      "<div style=\"font-size:64px;font-weight:800;letter-spacing:-.03em;margin:12px 0 28px\">" + esc(amount) + "</div>" +
      "<a href=\"" + esc(openUrl) + "\" style=\"display:inline-block;background:#0071e3;color:#fff;text-decoration:none;font-size:17px;font-weight:600;padding:14px 28px;border-radius:12px\">Open FareLookup</a>" +
      "</body></html>";
    res.setHeader("Content-Type", "text/html; charset=utf-8");
    res.setHeader("Cache-Control", "public, max-age=300");
    res.status(200).send(calcHtml);
    return;
  }

  /* Month snapshots land on the frozen month: take-home big, the rest
     of the numbers under it, one button to the app home. No redirect. */
  if(isMonth && snap){
    const s = snap;
    const monthHtml = "<!DOCTYPE html><html lang=\"en\"><head><meta charset=\"utf-8\">" +
      "<title>" + esc(title) + "</title>" +
      "<meta property=\"og:type\" content=\"website\">" +
      "<meta property=\"og:title\" content=\"" + esc(title) + "\">" +
      "<meta property=\"og:description\" content=\"Car service month snapshot — tap to open the app.\">" +
      "<meta property=\"og:image\" content=\"" + esc(ogImg) + "\">" +
      "<meta property=\"og:image:width\" content=\"1200\">" +
      "<meta property=\"og:image:height\" content=\"630\">" +
      "<meta name=\"twitter:card\" content=\"summary_large_image\">" +
      "</head><body style=\"font-family:-apple-system,sans-serif;text-align:center;padding:48px 20px;color:#111\">" +
      "<div style=\"font-size:17px;color:#666\">" + esc(route) + "</div>" +
      "<div style=\"font-size:64px;font-weight:800;letter-spacing:-.03em;margin:12px 0 4px\">" + esc(amount) + "</div>" +
      "<div style=\"font-size:15px;color:#666;margin-bottom:28px\">Take-home</div>" +
      "<div style=\"font-size:17px;line-height:1.9\">" +
        "Revenue " + esc(money(Number(s.snap_revenue))) + "<br>" +
        "Expenses " + esc(money(Number(s.snap_expenses))) + "<br>" +
        "Hours " + esc(String(Number(s.snap_hours))) + "<br>" +
        "Vehicle cost recovered " + esc(money(Number(s.snap_recovered))) +
      "</div>" +
      "<a href=\"https://farelookup.vercel.app/\" style=\"display:inline-block;background:#0071e3;color:#fff;text-decoration:none;font-size:17px;font-weight:600;padding:14px 28px;border-radius:12px;margin-top:28px\">Open FareLookup</a>" +
      "</body></html>";
    res.setHeader("Content-Type", "text/html; charset=utf-8");
    res.setHeader("Cache-Control", "public, max-age=300");
    res.status(200).send(monthHtml);
    return;
  }

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
