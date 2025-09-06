// functions/index.js

// --- Importações de Módulos ---
const {onDocumentWritten} = require("firebase-functions/v2/firestore");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {log, warn, error} = require("firebase-functions/logger");
const {defineString} = require("firebase-functions/params");

// Módulo Admin do Firebase para interagir com os serviços
const admin = require("firebase-admin");

// Módulo para fazer requisições HTTP
const axios = require("axios");

// --- Inicialização do Firebase Admin ---
admin.initializeApp();

// --- MELHORIA DE SEGURANÇA: Chave de API via Variável de Ambiente ---
// A chave agora é lida de uma configuração segura, e não diretamente do código.
const mapsApiKey = defineString("MAPS_API_KEY");


// --- Funções Auxiliares ---

/**
 * Converte um endereço em coordenadas geográficas (latitude e longitude).
 */
const geocodeAddress = async (address) => {
  // A função agora usa a variável de ambiente segura.
  const url = `https://maps.googleapis.com/maps/api/geocode/json?address=${encodeURIComponent(
      address,
  )}&key=${mapsApiKey.value()}`;
  try {
    const response = await axios.get(url);
    const {data} = response;
    if (data.status === "OK") {
      const location = data.results[0].geometry.location;
      return new admin.firestore.GeoPoint(location.lat, location.lng);
    } else {
      warn("Geocoding failed:", data.status);
      return null;
    }
  } catch (err) {
    error("Error calling Geocoding API:", err);
    return null;
  }
};


// --- Cloud Functions (Triggers do Firestore) ---

/**
 * Trigger que geocodifica o endereço de uma Escola ao ser criada/atualizada.
 */
exports.geocodeSchoolAddress = onDocumentWritten("schools/{schoolId}", async (event) => {
  const afterData = event.data?.after.data();
  if (!afterData) return;

  const address = `${afterData.address || ""}, ${afterData.city || ""}`;
  const oldAddress = `${event.data?.before.data()?.address || ""}, ${event.data?.before.data()?.city || ""}`;

  if (address === oldAddress) return;
  
  const geoPoint = await geocodeAddress(address);
  if (geoPoint) {
    return event.data.after.ref.set({location: geoPoint}, {merge: true});
  }
  return;
});

/**
 * Trigger que geocodifica o endereço de uma Empresa ao ser criada/atualizada.
 */
exports.geocodeCompanyAddress = onDocumentWritten("companies/{companyId}", async (event) => {
  const afterData = event.data?.after.data();
  if (!afterData) return;
  
  const address = `${afterData.address || ""}, ${afterData.cep || ""}`;
  const oldAddress = `${event.data?.before.data()?.address || ""}, ${event.data?.before.data()?.cep || ""}`;

  if (address === oldAddress) return;
    
  const geoPoint = await geocodeAddress(address);
  if (geoPoint) {
    return event.data.after.ref.set({location: geoPoint}, {merge: true});
  }
  return;
});


// --- Cloud Functions (Callable - Chamadas pelo App) ---

/**
 * Função chamada pelo app para criar um novo vendedor.
 */
exports.createSalesperson = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "É preciso estar autenticado.");
  }

  const callerDoc = await admin.firestore().collection("users").doc(request.auth.uid).get();
  if (!callerDoc.exists || callerDoc.data().role !== "super_admin") {
    throw new HttpsError("permission-denied", "Apenas Super Admins podem criar vendedores.");
  }

  const {name, email, password} = request.data;
  if (!name || !email || !password) {
    throw new HttpsError("invalid-argument", "Nome, e-mail e senha são obrigatórios.");
  }

  try {
    const userRecord = await admin.auth().createUser({
      email: email,
      password: password,
      displayName: name,
    });

    const batch = admin.firestore().batch();
    const userRef = admin.firestore().collection("users").doc(userRecord.uid);
    batch.set(userRef, {
      name: name,
      email: email,
      role: "salesperson",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const salespersonRef = admin.firestore().collection("salespeople").doc(userRecord.uid);
    batch.set(salespersonRef, {
      name: name,
      email: email,
      totalSalesValue: 0,
      salesCount: 0,
    });

    await batch.commit();

    log(`Vendedor ${name} criado com sucesso com o UID: ${userRecord.uid}`);
    return {success: true, message: `Vendedor ${name} criado com sucesso!`};
  } catch (error) {
    log("Erro ao criar vendedor:", error);
    throw new HttpsError("unknown", error.message || "Ocorreu um erro interno.");
  }
});

/**
 * NOVA FUNÇÃO: Apaga um vendedor (da Auth e do Firestore).
 */
exports.deleteSalesperson = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "É preciso estar autenticado.");
  }

  const callerDoc = await admin.firestore().collection("users").doc(request.auth.uid).get();
  if (!callerDoc.exists || callerDoc.data().role !== "super_admin") {
    throw new HttpsError("permission-denied", "Apenas Super Admins podem excluir vendedores.");
  }

  const userIdToDelete = request.data.uid;
  if (!userIdToDelete) {
    throw new HttpsError("invalid-argument", "O UID do vendedor é obrigatório.");
  }

  try {
    // 1. Apaga o usuário da Autenticação do Firebase
    await admin.auth().deleteUser(userIdToDelete);

    // 2. Apaga os documentos do Firestore
    const batch = admin.firestore().batch();
    batch.delete(admin.firestore().collection("users").doc(userIdToDelete));
    batch.delete(admin.firestore().collection("salespeople").doc(userIdToDelete));
    await batch.commit();

    log(`Vendedor com UID ${userIdToDelete} excluído com sucesso.`);
    return {success: true, message: "Vendedor excluído com sucesso!"};
  } catch (error) {
    log("Erro ao excluir vendedor:", error);
    throw new HttpsError("internal", error.message, error);
  }
});