// functions/index.js

// --- Importações de Módulos ---
// Módulos do Firebase para Cloud Functions V2
const {onDocumentWritten} = require("firebase-functions/v2/firestore");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {log, warn, error} = require("firebase-functions/logger");

// Módulo Admin do Firebase para interagir com os serviços (Auth, Firestore, etc.)
const admin = require("firebase-admin");

// Módulo para fazer requisições HTTP (usado para a API do Google Maps)
const axios = require("axios");

// --- Inicialização do Firebase Admin ---
// Deve ser chamado apenas uma vez no início do arquivo.
admin.initializeApp();

// --- Constantes e Configurações ---
// IMPORTANTE: Substitua 'SUA_CHAVE_DE_API_DO_GOOGLE_CLOUD' pela sua chave de API
const Maps_API_KEY = "AIzaSyCkWnthtl4WP5NMHA4ZLfg4rMvfE4qeHas";

// --- Funções Auxiliares ---

/**
 * Converte um endereço em coordenadas geográficas (latitude e longitude)
 * usando a API de Geocoding do Google Maps.
 * @param {string} address O endereço a ser geocodificado.
 * @return {admin.firestore.GeoPoint | null} Um GeoPoint ou null se falhar.
 */
const geocodeAddress = async (address) => {
  const url = `https://maps.googleapis.com/maps/api/geocode/json?address=${encodeURIComponent(
      address,
  )}&key=${Maps_API_KEY}`;
  try {
    const response = await axios.get(url);
    const {data} = response;
    if (data.status === "OK") {
      const location = data.results[0].geometry.location;
      // Atualizado para usar o namespace 'admin'
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
 * Trigger que é acionado quando um documento na coleção 'schools' é criado ou atualizado.
 * Converte o endereço da escola em coordenadas geográficas.
 */
exports.geocodeSchoolAddress = onDocumentWritten("schools/{schoolId}", async (event) => {
  const beforeData = event.data?.before.data();
  const afterData = event.data?.after.data();

  if (!afterData) {
    log("School document deleted, no action.");
    return;
  }

  const address = `${afterData.address || ""}, ${afterData.city || ""}`;
  const oldAddress = `${beforeData?.address || ""}, ${beforeData?.city || ""}`;

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

/**
 * Trigger que é acionado quando um documento na coleção 'companies' é criado ou atualizado.
 * Converte o endereço da empresa em coordenadas geográficas.
 */
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


// --- Cloud Functions (Callable - Chamadas pelo App) ---

/**
 * Função chamada pelo app para criar um novo vendedor.
 * Garante que apenas um 'super_admin' possa realizar esta ação.
 */
exports.createSalesperson = onCall(async (request) => {
  // 1. Verificação de Segurança:
  // Garante que o utilizador que está a chamar a função está autenticado.
  if (!request.auth) {
    throw new HttpsError(
        "unauthenticated",
        "É preciso estar autenticado para executar esta ação.",
    );
  }

  // 2. Verificação de Permissão:
  // Busca o documento do utilizador que chamou a função e verifica se ele é 'super_admin'.
  const callerDoc = await admin
      .firestore()
      .collection("users")
      .doc(request.auth.uid)
      .get();
  
  if (!callerDoc.exists || callerDoc.data().role !== "super_admin") {
    throw new HttpsError(
        "permission-denied",
        "Você não tem permissão para criar novos vendedores.",
    );
  }

  // 3. Extração e Validação dos Dados enviados pelo app
  const {name, email, password} = request.data;
  if (!name || !email || !password) {
    throw new HttpsError(
        "invalid-argument",
        "Dados incompletos. É necessário fornecer nome, email e senha.",
    );
  }

  try {
    // 4. Criação do Utilizador no Firebase Authentication
    const userRecord = await admin.auth().createUser({
      email: email,
      password: password,
      displayName: name,
    });

    // 5. Criação dos Documentos no Firestore em um batch
    const batch = admin.firestore().batch();

    // Documento na coleção 'users'
    const userRef = admin.firestore().collection("users").doc(userRecord.uid);
    batch.set(userRef, {
      name: name,
      email: email,
      role: "salesperson",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Documento na coleção 'salespeople'
    const salespersonRef = admin.firestore().collection("salespeople").doc(userRecord.uid);
    batch.set(salespersonRef, {
      name: name,
      email: email,
      totalSalesValue: 0,
      salesCount: 0,
    });

    await batch.commit();

    // 6. Retorno de Sucesso para o App
    const successMessage = `Vendedor ${name} criado com sucesso com o UID: ${userRecord.uid}`;
    log(successMessage);
    return {
      success: true,
      message: successMessage,
    };
  } catch (error) {
    // Tratamento de erros (ex: email já existe)
    log("Erro ao criar vendedor:", error);
    throw new HttpsError(
        "unknown",
        error.message || "Ocorreu um erro interno no servidor.",
    );
  }
});