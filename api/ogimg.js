"use strict";
/* Link-preview image: the quote amount, rendered as a PNG.
   Pure Node (zlib only) — a 5x7 bitmap font, uppercase, scaled up. */
const zlib = require("zlib");

const FONT = {
  "A":[14,17,17,31,17,17,17],"B":[30,17,17,30,17,17,30],"C":[14,17,16,16,16,17,14],
  "D":[28,18,17,17,17,18,28],"E":[31,16,16,30,16,16,31],"F":[31,16,16,30,16,16,16],
  "G":[14,17,16,23,17,17,15],"H":[17,17,17,31,17,17,17],"I":[14,4,4,4,4,4,14],
  "J":[7,2,2,2,2,18,12],"K":[17,18,20,24,20,18,17],"L":[16,16,16,16,16,16,31],
  "M":[17,27,21,21,17,17,17],"N":[17,25,21,19,17,17,17],"O":[14,17,17,17,17,17,14],
  "P":[30,17,17,30,16,16,16],"Q":[14,17,17,17,21,18,13],"R":[30,17,17,30,20,18,17],
  "S":[15,16,16,14,1,1,30],"T":[31,4,4,4,4,4,4],"U":[17,17,17,17,17,17,14],
  "V":[17,17,17,17,17,10,4],"W":[17,17,17,21,21,21,10],"X":[17,10,4,4,4,10,17],
  "Y":[17,10,4,4,4,4,4],"Z":[31,1,2,4,8,16,31],
  "0":[14,17,19,21,25,17,14],"1":[4,12,4,4,4,4,14],"2":[14,17,1,2,4,8,31],
  "3":[31,2,4,2,1,17,14],"4":[2,6,10,18,31,2,2],"5":[31,16,30,1,1,17,14],
  "6":[6,8,16,30,17,17,14],"7":[31,1,2,4,8,8,8],"8":[14,17,17,14,17,17,14],
  "9":[14,17,17,15,1,2,12],
  "$":[4,15,20,14,5,30,4],".":[0,0,0,0,0,12,12],",":[0,0,0,0,12,4,8],
  "/":[1,2,2,4,8,8,16],"-":[0,0,0,31,0,0,0],"(":[2,4,8,8,8,4,2],")":[8,4,2,2,2,4,8],
  "&":[12,18,20,8,21,18,13],"'":[4,4,8,0,0,0,0],"~":[0,0,13,22,0,0,0],
  ">":[8,4,2,1,2,4,8]," ":[0,0,0,0,0,0,0],"%":[25,26,2,4,8,11,19],
  "+":[0,4,4,31,4,4,0],"_":[0,0,0,0,0,0,31]
};

const W = 1200, H = 630;

function crc32(buf){
  let table = crc32.table;
  if(!table){
    table = crc32.table = [];
    for(let n = 0; n < 256; n++){
      let c = n;
      for(let k = 0; k < 8; k++) c = c & 1 ? 0xEDB88320 ^ (c >>> 1) : c >>> 1;
      table[n] = c >>> 0;
    }
  }
  let c = 0xFFFFFFFF;
  for(let i = 0; i < buf.length; i++) c = table[(c ^ buf[i]) & 0xFF] ^ (c >>> 8);
  return (c ^ 0xFFFFFFFF) >>> 0;
}
function chunk(type, data){
  const len = Buffer.alloc(4); len.writeUInt32BE(data.length, 0);
  const body = Buffer.concat([Buffer.from(type, "ascii"), data]);
  const crc = Buffer.alloc(4); crc.writeUInt32BE(crc32(body), 0);
  return Buffer.concat([len, body, crc]);
}
function makePng(pixels){
  const raw = Buffer.alloc(H * (1 + W * 3));
  for(let y = 0; y < H; y++){
    raw[y * (1 + W * 3)] = 0;
    pixels.copy(raw, y * (1 + W * 3) + 1, y * W * 3, (y + 1) * W * 3);
  }
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(W, 0); ihdr.writeUInt32BE(H, 4);
  ihdr[8] = 8; ihdr[9] = 2; // 8-bit RGB
  return Buffer.concat([
    Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
    chunk("IHDR", ihdr),
    chunk("IDAT", zlib.deflateSync(raw, { level: 6 })),
    chunk("IEND", Buffer.alloc(0))
  ]);
}

function drawText(px, text, cx, y, scale, color, bold){
  const clean = text.toUpperCase().replace(/→/g, ">").split("").map(ch => FONT[ch] ? ch : " ").join("");
  const charW = 6 * scale, totalW = clean.length * charW - scale;
  let x = Math.round(cx - totalW / 2);
  const off = bold ? Math.max(1, Math.round(scale * 0.22)) : 0;
  for(const ch of clean){
    const glyph = FONT[ch] || FONT[" "];
    for(let row = 0; row < 7; row++){
      for(let col = 0; col < 5; col++){
        if(!(glyph[row] & (16 >> col))) continue;
        for(let dy = 0; dy < scale; dy++){
          for(let dx = 0; dx < scale + off; dx++){
            const X = x + col * scale + dx, Y = y + row * scale + dy;
            if(X < 0 || X >= W || Y < 0 || Y >= H) continue;
            const i = (Y * W + X) * 3;
            px[i] = color[0]; px[i + 1] = color[1]; px[i + 2] = color[2];
          }
        }
      }
    }
    x += charW;
  }
  return totalW;
}

module.exports = async (req, res) => {
  const q = req.query || {};
  const amount = String(q.a || "").slice(0, 24) || "Fare Lookup";
  const route = String(q.r || "").slice(0, 64);

  const px = Buffer.alloc(W * H * 3, 255); // white
  const dark = [29, 29, 31], gray = [110, 110, 115], black = [0, 0, 0];

  if(route){
    let rs = 7;
    while(rs > 3 && (route.length * 6 * rs - rs) > 1120) rs -= 1;
    drawText(px, route, W / 2, 92, rs, gray, false);
  }

  // Amount: largest scale that fits 1080px wide
  let scale = 24;
  while(scale > 4 && (amount.length * 6 * scale - scale) > 1080) scale -= 2;
  const glyphH = 7 * scale;
  drawText(px, amount, W / 2, Math.round(315 - glyphH / 2) + (route ? 18 : 0), scale, black, true);


  const xtra = String(q.x || "").slice(0, 110);
  if(xtra){
    const xs = 4;
    const xw = (st) => st.length * 6 * xs - xs;
    const words = xtra.split(" ");
    const xlines = [""];
    for(const wd of words){
      const cand = xlines[xlines.length - 1] ? xlines[xlines.length - 1] + " " + wd : wd;
      if(xw(cand) > 1060 && xlines[xlines.length - 1]){ if(xlines.length < 2) xlines.push(wd); }
      else xlines[xlines.length - 1] = cand;
    }
    xlines.forEach((ln, i) => { if(ln) drawText(px, ln, W / 2, 448 + i * 36, xs, gray, false); });
  }
  drawText(px, "Car Service Fare Lookup", W / 2, H - 84, 4, gray, false);

  const png = makePng(px);
  res.writeHead(200, { "Content-Type": "image/png", "Cache-Control": "public, max-age=86400" });
  res.end(png);
};
