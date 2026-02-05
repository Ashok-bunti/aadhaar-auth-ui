import axios from "axios";
const BASE_URL = "http://127.0.0.1:8000";

export const uploadAadhaar = (file) => {
    const form = new FormData();
    form.append("file", file);
    return axios.post(`${BASE_URL}/upload-aadhaar`, form);
};

export const verifyFace = (selfie, aadhaarPath) => {
    const form = new FormData();
    form.append("live_file", selfie);
    return axios.post(`${BASE_URL}/verify-face?aadhaar_path=${encodeURIComponent(aadhaarPath)}`, form);
};

export const fetchAadhaarDirect = (aadhaarNumber) => {
    return axios.post(`${BASE_URL}/aadhaar-fetch-direct`, { aadhaar_number: aadhaarNumber });
};

export const uploadOfflineXML = (file, password) => {
    const form = new FormData();
    form.append("file", file);
    form.append("password", password);
    return axios.post(`${BASE_URL}/upload-offline-xml`, form);
};
