import { useState, useRef } from "react";
import { toast } from "react-toastify";
import { uploadAadhaar, fetchAadhaarDirect, uploadOfflineXML } from "../services/api";
import { API_BASE_URL } from "../services/config";
import { Upload, CheckCircle, FileText, ArrowRight, Loader2, ShieldCheck, X, Download, Eye, EyeOff } from "lucide-react";

export default function KycForm({ onSuccess }) {
    const [mode, setMode] = useState("offline"); // 'direct', 'upload', or 'offline'
    const [aadhaarNumber, setAadhaarNumber] = useState("");
    const [xmlPassword, setXmlPassword] = useState("");
    const [xmlFile, setXmlFile] = useState(null);
    const [showPassword, setShowPassword] = useState(false);

    const [file, setFile] = useState(null);
    const [loading, setLoading] = useState(false);
    const [extractedInfo, setExtractedInfo] = useState(null);
    const [isConfirmed, setIsConfirmed] = useState(null);
    const [hasError, setHasError] = useState(false);
    const fileInputRef = useRef(null);

    const handleDirectFetch = async () => {
        if (aadhaarNumber.length !== 12) {
            toast.error("Enter a valid 12-digit Aadhaar number");
            return;
        }
        setLoading(true);
        try {
            const res = await fetchAadhaarDirect(aadhaarNumber);
            toast.success("Identity Details Fetched!");
            setExtractedInfo({
                photo: res.data.data.aadhaar_photo,
                details: res.data.data
            });
        } catch (err) {
            toast.error("Failed to fetch details. Please try manual upload.");
        } finally {
            setLoading(false);
        }
    };

    const handleOfflineXML = async () => {
        if (!xmlFile) {
            toast.error("Please select a ZIP file from UIDAI");
            return;
        }
        if (!xmlPassword) {
            toast.error("Enter password (Pincode + First 4 letters of name)");
            return;
        }
        setLoading(true);
        try {
            const res = await uploadOfflineXML(xmlFile, xmlPassword);
            toast.success("Offline e-KYC Verified!");
            setExtractedInfo({
                photo: res.data.aadhaar_photo,
                details: res.data.details
            });
        } catch (err) {
            const msg = err.response?.data?.detail || "Verification failed. Check password format.";
            toast.error(msg);
        } finally {
            setLoading(false);
        }
    };

    const handleFileChange = (e) => {
        const selectedFile = e.target.files[0];
        if (selectedFile) {
            const allowedTypes = ['image/jpeg', 'image/png', 'application/pdf', 'image/jpg'];
            if (!allowedTypes.includes(selectedFile.type)) {
                toast.error("Invalid file format! Please upload JPG, PNG, or PDF.");
                return;
            }
            setFile(selectedFile);
            setExtractedInfo(null);
            setIsConfirmed(null);
            setHasError(false);
        }
        e.target.value = '';
    };

    const triggerFileInput = () => fileInputRef.current.click();
    const handleRemoveFile = (e) => { e.stopPropagation(); setFile(null); setExtractedInfo(null); };

    const submit = async () => {
        if (!file) return;
        setLoading(true);
        setHasError(false);
        try {
            const res = await uploadAadhaar(file);
            toast.success("Identity data captured!");
            setExtractedInfo({
                photo: res.data.aadhaar_photo,
                details: res.data.details
            });
        } catch (error) {
            setHasError(true);
            toast.error("Process failed. Use Aadhaar Number method if OCR fails.");
        } finally {
            setLoading(false);
        }
    };

    const handleProceed = () => {
        if (extractedInfo && isConfirmed === true) {
            onSuccess(extractedInfo.photo, extractedInfo.details);
        }
    };

    return (
        <div className="card">
            <div className="steps">
                <div className="step active"></div>
                <div className="step"></div>
            </div>

            <div className="card-header">
                <h1 className="card-title">Identity Verification</h1>
                <p className="card-subtitle">Choose your preferred verification method</p>

                {!extractedInfo && (
                    <div className="mode-tabs" style={{ display: 'flex', gap: '8px', marginTop: '20px', background: '#f8fafc', padding: '5px', borderRadius: '12px' }}>
                        <button
                            onClick={() => setMode('direct')}
                            style={{ flex: 1, padding: '8px', borderRadius: '8px', border: 'none', background: mode === 'direct' ? 'white' : 'transparent', fontWeight: '600', color: mode === 'direct' ? 'var(--primary)' : '#64748b', transition: 'all 0.3s', boxShadow: mode === 'direct' ? '0 2px 4px rgba(0,0,0,0.05)' : 'none', cursor: 'pointer', fontSize: '13px' }}
                        >Aadhaar Number</button>
                        <button
                            onClick={() => setMode('offline')}
                            style={{ flex: 1, padding: '8px', borderRadius: '8px', border: 'none', background: mode === 'offline' ? 'white' : 'transparent', fontWeight: '600', color: mode === 'offline' ? 'var(--primary)' : '#64748b', transition: 'all 0.3s', boxShadow: mode === 'offline' ? '0 2px 4px rgba(0,0,0,0.05)' : 'none', cursor: 'pointer', fontSize: '13px' }}
                        >Offline XML</button>

                    </div>
                )}
            </div>

            {!extractedInfo ? (
                <>
                    {mode === 'direct' ? (
                        <div className="otp-container" style={{ padding: '20px 0' }}>
                            <div className="input-group" style={{ marginBottom: '20px' }}>
                                <label className="detail-label">Aadhaar Number</label>
                                <input
                                    type="text"
                                    maxLength="12"
                                    placeholder="0000 0000 0000"
                                    value={aadhaarNumber}
                                    onChange={(e) => setAadhaarNumber(e.target.value.replace(/\D/g, ""))}
                                    style={{ width: '100%', padding: '14px', borderRadius: '12px', border: '1px solid #e2e8f0', fontSize: '18px', letterSpacing: '2px', textAlign: 'center', marginTop: '8px' }}
                                />
                            </div>

                            <button className="btn-primary" onClick={handleDirectFetch} disabled={aadhaarNumber.length !== 12 || loading}>
                                {loading ? <Loader2 className="animate-spin" /> : <ShieldCheck />}
                                Fetch Identity Details
                            </button>
                            <p style={{ fontSize: '12px', color: '#64748b', marginTop: '16px', textAlign: 'center' }}>
                                Details will be retrieved instantly for the provided UID.
                            </p>
                        </div>
                    ) : mode === 'offline' ? (
                        <div className="offline-container" style={{ padding: '0px 0 20px 0', marginTop: '-10px' }}>
                            <div className="info-section" style={{ marginBottom: '15px', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '6px', color: '#0f172a' }}>
                                <Download size={14} style={{ minWidth: '14px', color: '#dc2626' }} />
                                <p style={{ fontSize: '12px', margin: 0, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                                    <strong style={{ color: '#dc2626' }}>E-Aadhaar:</strong> Visit <a href="https://myaadhaar.uidai.gov.in" target="_blank" rel="noopener noreferrer" style={{ color: '#2563eb', textDecoration: 'underline' }}>myaadhaar.uidai.gov.in</a> to download your ZIP file
                                </p>
                            </div>

                            <div className="input-group" style={{ marginBottom: '20px' }}>
                                <label className="detail-label">Upload PDF File</label>
                                <div
                                    onClick={() => document.getElementById('pdf-upload-input').click()}
                                    style={{
                                        marginTop: '8px',
                                        border: '2px dashed #cbd5e1',
                                        borderRadius: '12px',
                                        padding: '20px',
                                        textAlign: 'center',
                                        cursor: 'pointer',
                                        transition: 'all 0.2s',
                                        background: xmlFile ? '#f0fdf4' : '#ffffff',
                                        borderColor: xmlFile ? '#16a34a' : '#cbd5e1'
                                    }}
                                    className="custom-file-upload-zone"
                                >
                                    <input
                                        id="pdf-upload-input"
                                        type="file"
                                        accept=".zip,.pdf"
                                        onChange={(e) => setXmlFile(e.target.files[0])}
                                        style={{ display: 'none' }}
                                    />

                                    {!xmlFile ? (
                                        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '8px', color: '#64748b' }}>
                                            <Upload size={24} color="#94a3b8" />
                                            <span style={{ fontSize: '14px', fontWeight: '500' }}>Click to Browse PDF</span>
                                        </div>
                                    ) : (
                                        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '10px', color: '#16a34a' }}>
                                            <div style={{ background: '#dcfce7', padding: '8px', borderRadius: '50%' }}>
                                                <FileText size={20} />
                                            </div>
                                            <span style={{ fontSize: '14px', fontWeight: '600', maxWidth: '200px', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                                                {xmlFile.name}
                                            </span>
                                            <button
                                                onClick={(e) => { e.stopPropagation(); setXmlFile(null); }}
                                                style={{ border: 'none', background: 'none', cursor: 'pointer', color: '#ef4444', padding: '4px' }}
                                            >
                                                <X size={16} />
                                            </button>
                                        </div>
                                    )}
                                </div>
                            </div>

                            <div className="input-group" style={{ marginBottom: '20px' }}>
                                <label className="detail-label">Password</label>
                                <div style={{ position: 'relative', marginTop: '8px' }}>
                                    <input
                                        type={showPassword ? "text" : "password"}
                                        placeholder="e.g., AAAA1234"
                                        value={xmlPassword}
                                        onChange={(e) => setXmlPassword(e.target.value.toUpperCase())}
                                        style={{ width: '100%', padding: '14px', paddingRight: '45px', borderRadius: '12px', border: '1px solid #e2e8f0', fontSize: '14px', fontFamily: 'monospace' }}
                                    />
                                    <button
                                        type="button"
                                        onClick={() => setShowPassword(!showPassword)}
                                        style={{ position: 'absolute', right: '12px', top: '50%', transform: 'translateY(-50%)', background: 'none', border: 'none', cursor: 'pointer', color: '#64748b' }}
                                    >
                                        {showPassword ? <EyeOff size={18} /> : <Eye size={18} />}
                                    </button>
                                </div>
                                <p style={{ fontSize: '11px', color: '#64748b', marginTop: '6px' }}>
                                    Format: First 4 letters of your name (uppercase) + Birth Year (YYYY)
                                </p>
                            </div>

                            <button className="btn-primary" onClick={handleOfflineXML} disabled={!xmlFile || !xmlPassword || loading}>
                                {loading ? <Loader2 className="animate-spin" /> : <ShieldCheck />}
                                Verify Offline e-KYC
                            </button>
                        </div>
                    ) : null}
                </>
            ) : (
                <div className="extracted-details" style={{ marginTop: '0' }}>
                    <div className="id-card-container" style={{
                        background: '#ffffff',
                        borderRadius: '12px',
                        padding: '24px',
                        border: '1px solid #e2e8f0',
                        boxShadow: '0 4px 6px -1px rgba(0,0,0,0.1)',
                        marginBottom: '24px'
                    }}>
                        {/* TOP ROW: PHOTO + BASIC DETAILS */}
                        <div style={{ display: 'flex', gap: '24px', alignItems: 'flex-start', marginBottom: '20px' }}>
                            {/* LEFT: PHOTO */}
                            <div style={{ flexShrink: 0 }}>
                                {extractedInfo.photo ? (
                                    <img
                                        src={extractedInfo.photo.includes('data:image') || extractedInfo.photo.includes('http')
                                            ? extractedInfo.photo
                                            : `${API_BASE_URL}/${extractedInfo.photo.replace(/\\/g, '/')}`}

                                        alt="Aadhaar Photo"
                                        style={{
                                            width: '130px',
                                            height: '160px',
                                            objectFit: 'cover',
                                            borderRadius: '8px',
                                            background: '#f1f5f9',
                                            border: '1px solid #e2e8f0'
                                        }}
                                        onError={(e) => {
                                            if (!e.target.src.includes('placeholder')) {
                                                e.target.src = "https://via.placeholder.com/130x160?text=Photo";
                                            }
                                        }}
                                    />
                                ) : (
                                    <div style={{ width: '130px', height: '160px', background: '#f1f5f9', borderRadius: '8px', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                                        <span style={{ fontSize: '12px', color: '#94a3b8' }}>No Photo</span>
                                    </div>
                                )}
                            </div>

                            {/* RIGHT: DETAILS (UID, DOB, GENDER) */}
                            <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: '0' }}>
                                {/* Aadhaar Number (Header) */}
                                <div style={{ paddingBottom: '12px', borderBottom: '1px solid #e2e8f0', marginBottom: '12px' }}>
                                    <label style={{ fontSize: '11px', color: '#64748b', textTransform: 'uppercase', letterSpacing: '0.5px' }}>Aadhaar Number</label>
                                    <h3 style={{ margin: '4px 0 0 0', fontSize: '20px', fontWeight: '700', color: '#0f172a', letterSpacing: '1px' }}>
                                        {extractedInfo.details.uid}
                                    </h3>
                                </div>

                                {/* DOB */}
                                <div style={{ display: 'flex', alignItems: 'center', paddingBottom: '12px', borderBottom: '1px solid #e2e8f0', marginBottom: '12px' }}>
                                    <strong style={{ fontSize: '15px', color: '#334155', minWidth: '80px' }}>DOB:</strong>
                                    <span style={{ fontSize: '16px', fontWeight: '600', color: '#0f172a' }}>{extractedInfo.details.dob}</span>
                                </div>

                                {/* Gender */}
                                <div style={{ display: 'flex', alignItems: 'center' }}>
                                    <strong style={{ fontSize: '15px', color: '#334155', minWidth: '80px' }}>Gender:</strong>
                                    <span style={{ fontSize: '16px', fontWeight: '600', color: '#0f172a' }}>{extractedInfo.details.gender}</span>
                                </div>
                            </div>
                        </div>

                        {/* BOTTOM ROW: FULL WIDTH ADDRESS */}
                        <div style={{ paddingTop: '16px', borderTop: '1px dashed #e2e8f0' }}>
                            <strong style={{ fontSize: '15px', color: '#334155', display: 'block', marginBottom: '8px' }}>Address:</strong>
                            <p style={{ margin: 0, fontSize: '14px', lineHeight: '1.6', color: '#475569' }}>
                                {extractedInfo.details.address}
                            </p>
                        </div>
                    </div>

                    {/* CONFIRMATION BUTTONS */}
                    <div className="confirmation-section" style={{
                        marginTop: '0px',
                        padding: '20px',
                        background: '#f1f5f9',
                        borderRadius: '14px',
                        border: '1px solid #e2e8f0'
                    }}>
                        <p style={{ fontSize: '14px', fontWeight: '600', marginBottom: '15px', textAlign: 'center', color: '#1e293b' }}>Are these details accurate?</p>
                        <div style={{ display: 'flex', gap: '10px' }}>
                            <button
                                className="confirm-btn"
                                onClick={() => onSuccess(extractedInfo.photo, extractedInfo.details)}
                                style={{
                                    flex: 1,
                                    padding: '12px',
                                    borderRadius: '10px',
                                    border: 'none',
                                    background: 'var(--primary)',
                                    color: 'white',
                                    cursor: 'pointer',
                                    fontWeight: '700',
                                    boxShadow: '0 2px 4px rgba(0,0,0,0.05)'
                                }}
                            >
                                Yes, Proceed
                            </button>
                            <button
                                className="reject-btn"
                                onClick={() => setExtractedInfo(null)}
                                style={{
                                    flex: 1,
                                    padding: '12px',
                                    borderRadius: '10px',
                                    border: '1px solid #e2e8f0',
                                    background: 'white',
                                    color: '#64748b',
                                    cursor: 'pointer',
                                    fontWeight: '700',
                                    boxShadow: '0 2px 4px rgba(0,0,0,0.05)'
                                }}
                            >
                                No, Re-upload
                            </button>
                        </div>
                    </div>

                    <div style={{ marginTop: '20px', textAlign: 'center' }}>
                        <button
                            onClick={() => setExtractedInfo(null)}
                            style={{
                                background: 'none',
                                border: 'none',
                                color: '#94a3b8',
                                fontSize: '12px',
                                cursor: 'pointer'
                            }}
                        >
                            Cancel & Change File
                        </button>
                    </div>
                </div>
            )}

            <div className="footer-text">
                <ShieldCheck size={16} />
                <span>End-to-End Encryption Enabled</span>
            </div>
        </div>
    );
}
