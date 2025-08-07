// functions/index.js

const {onDocumentWritten} = require("firebase-functions/v2/firestore");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore, GeoPoint} = require("firebase-admin/firestore");
const {log, warn, error} = require("firebase-functions/logger");
const axios = require("axios");

initializeApp();

// IMPORTANTE: Substitua 'SUA_CHAVE_DE_API_DO_GOOGLE_CLOUD' pela sua chave de API
const Maps_API_KEY = "AIzaSyCkWnthtl4WP5NMHA4ZLfg4rMvfE4qeHas";

// Função para fazer o geocoding
const geocodeAddress = async (address) => {
  const url = `https://maps.googleapis.com/maps/api/geocode/json?address=${encodeURIComponent(
    address,
  )}&key=${Maps_API_KEY}`;
  try {
    const response = await axios.get(url);
    const {data} = response;
    if (data.status === "OK") {
      const location = data.results[0].geometry.location;
      return new GeoPoint(location.lat, location.lng);
    } else {
      warn("Geocoding failed:", data.status);
      return null;
    }
  } catch (err) {
    error("Error calling Geocoding API:", err);
    return null;
  }
};

// SINTAXE ATUALIZADA: Função "robô" para escolas
exports.geocodeSchoolAddress = onDocumentWritten("schools/{schoolId}", async (event) => {
  // Em V2, os dados 'before' e 'after' estão dentro de event.data
  const beforeData = event.data?.before.data();
  const afterData = event.data?.after.data();

  // Se o documento foi apagado ou não tem dados, não faz nada
  if (!afterData) {
    log("School document deleted, no action.");
    return;
  }

  const address = `${afterData.address || ""}, ${afterData.city || ""}`;
  const oldAddress = `${beforeData?.address || ""}, ${beforeData?.city || ""}`;

  // Evita loops infinitos: só executa se o endereço mudou
  if (address === oldAddress) {
    log("School address unchanged, no action.");
    return;
  }
  
  log(`Geocoding new school address: ${address}`);
  const geoPoint = await geocodeAddress(address);

  if (geoPoint) {
    log(`Geocoding successful for school ${event.params.schoolId}. Updating document.`);
    return event.data.after.ref.set({location: geoPoint}, {merge: true});
  }
  return;
});

// SINTAXE ATUALIZADA: Função "robô" para empresas
exports.geocodeCompanyAddress = onDocumentWritten("companies/{companyId}", async (event) => {
  const beforeData = event.data?.before.data();
  const afterData = event.data?.after.data();

  if (!afterData) {
    log("Company document deleted, no action.");
    return;
  }
  
  const address = `${afterData.address || ""}, ${afterData.cep || ""}`;
  const oldAddress = `${beforeData?.address || ""}, ${beforeData?.cep || ""}`;

  if (address === oldAddress) {
    log("Company address unchanged, no action.");
    return;
  }
    
  log(`Geocoding new company address: ${address}`);
  const geoPoint = await geocodeAddress(address);

  if (geoPoint) {
    log(`Geocoding successful for company ${event.params.companyId}. Updating document.`);
    return event.data.after.ref.set({location: geoPoint}, {merge: true});
  }
  return;
});