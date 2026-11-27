"use strict";
const OWNER = "5ef9a6f2-14c6-4325-a934-e98e20110fa7";
const SB = "https://axmamofelrnewhbtkwlu.supabase.co";
const KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF4bWFtb2ZlbHJuZXdoYnRrd2x1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTQzNjY3MzIsImV4cCI6MjEwOTk0MjczMn0.k7eq_pGtEsC9I7nv5AWQ9lk1AhsfmbxH4jrAMXXdsH4";
async function readAximote(path){
  const response = await fetch("https://api.aximote.com/api/public/v1/" + path,{
    headers:{Authorization:"Bearer " + process.env.aximote_key},redirect:"error",signal:AbortSignal.timeout(10000)
  });
  if(!response.ok) throw new Error("Aximote returned " + response.status);
  return response.json();
}
function units(value,divisor){
  return Number.isFinite(value) && value >= 0 ? value / divisor : null;
}
module.exports = async function handler(req,res){
  res.setHeader("Cache-Control","private, no-store");
  if(req.method !== "GET") return res.status(405).end();
  const authorization = req.headers.authorization || "";
  if(!/^Bearer [^\s]+$/.test(authorization)) return res.status(401).end();
  try{
    const auth = await fetch(SB + "/auth/v1/user",{headers:{apikey:KEY,authorization},redirect:"error",signal:AbortSignal.timeout(8000)});
    if(!auth.ok) return res.status(401).end();
    const user = await auth.json();
    if(user.id !== OWNER) return res.status(403).end();
    if(!process.env.aximote_key) return res.status(503).json({error:"Aximote key unavailable on this deployment."});
    const vehicles = await readAximote("vehicles");
    const trips = [];
    for(const vehicle of vehicles){
      const page = await readAximote("trips?limit=50&vehicleId=" + encodeURIComponent(vehicle.id));
      for(const trip of page.items){
        if(!trip.startTime || !Number.isFinite(Date.parse(trip.startTime))) throw new Error("Invalid trip date");
        trips.push({source_key:"api:" + vehicle.id + ":" + (trip.id ?? trip.startTime),
          started_at:trip.startTime,ended_at:trip.endTime ?? null,distance_mi:units(trip.distanceKm,1.609344),
          duration_minutes:units(trip.durationSec,60),fuel_gallons:units(trip.fuelConsumedL,3.785411784)});
      }
    }
    return res.status(200).json({trips});
  }catch{
    return res.status(502).json({error:"Could not retrieve drives. Check the connection and try again."});
  }
};
