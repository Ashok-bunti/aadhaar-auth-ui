import { useRef, useState, useCallback, useEffect } from "react";
import Webcam from "react-webcam";
import * as faceapi from "face-api.js";
import { Loader2, ShieldCheck, Undo, Check, AlertCircle, Sparkles, Eye } from "lucide-react";

export default function Camera({ onCapture, onBack, details }) {
    const webcamRef = useRef(null);
    const [isCapturing, setIsCapturing] = useState(false);
    const [imgSrc, setImgSrc] = useState(null);
    const [modelsLoaded, setModelsLoaded] = useState(false);
    const [verificationStatus, setVerificationStatus] = useState({
        faceInPosition: false,
        goodLighting: false,
        noGlasses: true,
        blinkDetected: false,
        message: "Initializing AI..."
    });
    const [borderClass, setBorderClass] = useState("border-red");
    const [verificationResult, setVerificationResult] = useState(null);


    // Load models
    useEffect(() => {
        const loadModels = async () => {
            const MODEL_URL = "/models";
            try {
                await Promise.all([
                    faceapi.nets.tinyFaceDetector.loadFromUri(MODEL_URL),
                    faceapi.nets.faceLandmark68Net.loadFromUri(MODEL_URL),
                    faceapi.nets.faceExpressionNet.loadFromUri(MODEL_URL)
                ]);
                setModelsLoaded(true);
                setVerificationStatus(prev => ({ ...prev, message: "Position your face in the frame" }));
            } catch (err) {
                console.error("Model loading failed", err);
                setVerificationStatus(prev => ({ ...prev, message: "AI Engine Error - Check Connection" }));
            }
        };
        loadModels();
    }, []);

    const detectBlink = (landmarks) => {
        const leftEye = landmarks.getLeftEye();
        const rightEye = landmarks.getRightEye();

        const getEAR = (eye) => {
            const p2_p6 = Math.sqrt(Math.pow(eye[1].x - eye[5].x, 2) + Math.pow(eye[1].y - eye[5].y, 2));
            const p3_p5 = Math.sqrt(Math.pow(eye[2].x - eye[4].x, 2) + Math.pow(eye[2].y - eye[4].y, 2));
            const p1_p4 = Math.sqrt(Math.pow(eye[0].x - eye[3].x, 2) + Math.pow(eye[0].y - eye[3].y, 2));
            return (p2_p6 + p3_p5) / (2.0 * p1_p4);
        };

        const ear = (getEAR(leftEye) + getEAR(rightEye)) / 2;
        return ear < 0.22; // Threshold for blink
    };

    const handleCapture = useCallback(() => {
        if (webcamRef.current) {
            const imageSrc = webcamRef.current.getScreenshot();
            setImgSrc(imageSrc);
        }
    }, [webcamRef]);

    const [stabilityCount, setStabilityCount] = useState(0);
    const [faceLandmarks, setFaceLandmarks] = useState(null);

    const blinkRef = useRef(false);
    const lastBlinkTime = useRef(0);

    // Heuristic for Glasses Detection: Checks for landmark confidence and region contrast
    const checkNoGlasses = (landmarks, video) => {
        try {
            const nose = landmarks.getNose();
            const leftEye = landmarks.getLeftEye();
            const rightEye = landmarks.getRightEye();

            // 1. Landmark based check (Bridge occlusion)
            const bridgeGap = Math.abs(rightEye[0].x - leftEye[3].x);
            const eyeWidth = Math.abs(leftEye[3].x - leftEye[0].x);

            // 2. Pixel-level contrast check on the bridge (Premium Check)
            const canvas = document.createElement('canvas');
            canvas.width = 40; canvas.height = 20;
            const ctx = canvas.getContext('2d');

            // Map the nose bridge area
            const bridgeX = nose[0].x - 20;
            const bridgeY = nose[0].y - 10;
            ctx.drawImage(video, bridgeX, bridgeY, 40, 20, 0, 0, 40, 20);

            const imageData = ctx.getImageData(0, 0, 40, 20).data;
            let contrastSum = 0;

            // Look for horizontal edges (typical of glasses frames)
            for (let y = 1; y < 19; y++) {
                for (let x = 0; x < 40; x++) {
                    const idx = (y * 40 + x) * 4;
                    const prevIdx = ((y - 1) * 40 + x) * 4;
                    const diff = Math.abs(imageData[idx] - imageData[prevIdx]);
                    if (diff > 35) contrastSum++; // High contrast edge found
                }
            }

            // If too many "edges" are found in the bridge area, it's likely glasses
            const hasFrames = contrastSum > 50;
            const hasGoodGap = (bridgeGap / eyeWidth) > 0.6;

            return !hasFrames && hasGoodGap;
        } catch (e) {
            return true; // Fallback to safe
        }
    };

    // Main AI Loop
    useEffect(() => {
        let timer;

        const runAnalysis = async () => {
            if (modelsLoaded && webcamRef.current && webcamRef.current.video && webcamRef.current.video.readyState === 4 && !imgSrc) {
                const video = webcamRef.current.video;

                // CRITICAL: Ensure video has dimensions before running analysis
                if (video.videoWidth === 0 || video.videoHeight === 0) {
                    timer = setTimeout(runAnalysis, 100);
                    return;
                }

                const detections = await faceapi.detectSingleFace(video, new faceapi.TinyFaceDetectorOptions({ inputSize: 224, scoreThreshold: 0.5 }))
                    .withFaceLandmarks();

                if (detections) {
                    const dims = faceapi.matchDimensions(video, video, true);
                    const resizedDetections = faceapi.resizeResults(detections, dims);
                    const landmarks = resizedDetections.landmarks;
                    setFaceLandmarks(landmarks.positions);

                    // 1. Position Check (Maximum Oval Bounds)
                    const { x, y, width, height } = resizedDetections.detection.box;
                    const midX = x + width / 2;
                    const midY = y + height / 2;

                    const centerCheckX = midX > video.videoWidth * 0.1 && midX < video.videoWidth * 0.9;
                    const centerCheckY = midY > video.videoHeight * 0.1 && midY < video.videoHeight * 0.9;
                    const sizeCheck = height > video.videoHeight * 0.3 && height < video.videoHeight * 0.98;

                    // 2. Head Pose (Roll & Yaw)
                    const jaw = landmarks.getJawOutline();
                    const nosePos = landmarks.getNose()[0];
                    const roll = Math.abs(Math.atan2(landmarks.getRightEye()[3].y - landmarks.getLeftEye()[0].y, landmarks.getRightEye()[3].x - landmarks.getLeftEye()[0].x) * (180 / Math.PI));
                    const yawValue = Math.abs(((nosePos.x - jaw[0].x) / (jaw[16].x - nosePos.x)) - 1.0);
                    const okPose = roll < 25 && yawValue < 0.8;

                    // 3. Lighting Check
                    const canvas = document.createElement('canvas');
                    canvas.width = 64; canvas.height = 64;
                    const ctx = canvas.getContext('2d');
                    ctx.drawImage(video, 0, 0, 64, 64);
                    const brightness = ctx.getImageData(0, 0, 64, 64).data.reduce((acc, val, i) => i % 4 !== 3 ? acc + val : acc, 0) / (64 * 64 * 3);
                    const okLighting = brightness > 50;

                    // 4. Glasses Heuristic (Pixel-level edge detection)
                    const noGlassesCheck = checkNoGlasses(landmarks, video);

                    // 5. Stability Check
                    const okPosition = centerCheckX && centerCheckY && sizeCheck && okPose;
                    if (okPosition && okLighting) {
                        setStabilityCount(prev => Math.min(prev + 1, 10));
                    } else {
                        setStabilityCount(0);
                    }

                    // 6. Blink Detection (Very Sensitive EAR 0.28)
                    const getEAR = (eye) => {
                        const p2_p6 = Math.sqrt(Math.pow(eye[1].x - eye[5].x, 2) + Math.pow(eye[1].y - eye[5].y, 2));
                        const p3_p5 = Math.sqrt(Math.pow(eye[2].x - eye[4].x, 2) + Math.pow(eye[2].y - eye[4].y, 2));
                        const p1_p4 = Math.sqrt(Math.pow(eye[0].x - eye[3].x, 2) + Math.pow(eye[0].y - eye[3].y, 2));
                        return (p2_p6 + p3_p5) / (2.0 * p1_p4);
                    };
                    const ear = (getEAR(landmarks.getLeftEye()) + getEAR(landmarks.getRightEye())) / 2;
                    const blink = ear < 0.28;

                    let detectedNewBlink = false;
                    const now = Date.now();

                    if (blink && !blinkRef.current && (now - lastBlinkTime.current > 800)) {
                        blinkRef.current = true;
                        detectedNewBlink = true;
                        lastBlinkTime.current = now;
                    } else if (!blink && blinkRef.current) {
                        blinkRef.current = false;
                    }

                    const isStable = stabilityCount >= 3; // Ultra-fast stable lock

                    const status = {
                        faceInPosition: okPosition,
                        goodLighting: okLighting,
                        noGlasses: noGlassesCheck,
                        blinkDetected: blinkRef.current,
                        message: !okPosition ? "Fit face in frame" :
                            !okLighting ? "Area too dark" :
                                !noGlassesCheck ? "Remove glasses" :
                                    !isStable ? "Holding still..." : "BLINK NOW TO CAPTURE"
                    };

                    setVerificationStatus(status);
                    setBorderClass((okPosition && okLighting && noGlassesCheck) ? "border-green" : "border-red");

                    if (isStable && detectedNewBlink) {
                        handleCapture();
                        const audio = new Audio("https://assets.mixkit.co/active_storage/sfx/2358/2358-preview.mp3");
                        audio.play().catch(() => { });
                    }
                } else {
                    setFaceLandmarks(null);
                    setVerificationStatus(v => ({ ...v, faceInPosition: false, message: "Scanning for face..." }));
                    setBorderClass("border-red");
                    setStabilityCount(0);
                }
            }
            timer = setTimeout(runAnalysis, 80); // Higher frequency for better tracking
        };

        runAnalysis();
        return () => clearTimeout(timer);
    }, [modelsLoaded, imgSrc, handleCapture, stabilityCount]);



    const handleRetake = () => {
        setImgSrc(null);
    };

    const handleConfirm = async () => {
        if (imgSrc) {
            setIsCapturing(true);
            setVerificationResult(null);
            const result = await onCapture(imgSrc);
            setVerificationResult(result);
            setIsCapturing(false);
        }
    };

    return (
        <div className="card face-card">
            <div className="steps">
                <div className="step active" style={{ background: 'var(--success)' }}></div>
                <div className="step active"></div>
            </div>

            <div className="card-header">
                <h1 className="card-title">Live Biometric</h1>
                <p className="card-subtitle">
                    {imgSrc ? "Verify your live portrait" : verificationStatus.message}
                </p>
            </div>

            <div className={`webcam-frame ${borderClass}`}>
                {imgSrc ? (
                    <div className="captured-container">
                        <img
                            src={imgSrc}
                            alt="Captured face"
                            className={`webcam-video ${isCapturing || verificationResult ? 'blur-sm' : ''}`}
                        />
                        {isCapturing && (
                            <div className="verification-loading">
                                <Loader2 size={40} className="animate-spin" />
                                <span>Verifying Identity...</span>
                            </div>
                        )}
                        {verificationResult && (
                            <div className={`verification-result-overlay ${verificationResult.verified ? 'success' : 'failure'}`}>
                                {verificationResult.verified ? <ShieldCheck size={48} /> : <AlertCircle size={48} />}
                                <h2>{verificationResult.verified ? "Identity Verified" : "Verification Failed"}</h2>
                                <p>{verificationResult.verified ? "Face biometric matches Aadhaar record." : "Live photo does not match document."}</p>
                            </div>
                        )}
                    </div>
                ) : (
                    <>
                        <Webcam
                            audio={false}
                            ref={webcamRef}
                            screenshotFormat="image/jpeg"
                            className="webcam-video"
                            videoConstraints={{ facingMode: "user", width: 640, height: 480 }}
                        />
                        <div className="face-overlay">
                            <svg viewBox="0 0 100 100" className="face-mask">
                                <path
                                    fill="none"
                                    stroke="currentColor"
                                    strokeWidth="0.5"
                                    strokeDasharray="2 2"
                                    d="M50,10 C25,10 15,35 15,50 C15,65 25,90 50,90 C75,90 85,65 85,50 C85,35 75,10 50,10 Z"
                                />
                            </svg>
                        </div>

                        {faceLandmarks && (
                            <div className="scanning-points">
                                {faceLandmarks.slice(0, 68).map((p, i) => (
                                    <div
                                        key={i}
                                        className="scanner-dot"
                                        style={{ left: `${(p.x / 640) * 100}%`, top: `${(p.y / 480) * 100}%` }}
                                    ></div>
                                ))}
                            </div>
                        )}

                        <div className={`live-hint ${borderClass === 'border-green' ? 'success' : 'warning'}`}>
                            {borderClass === 'border-green' ? <Sparkles size={14} /> : <AlertCircle size={14} />}
                            <span>{verificationStatus.message}</span>
                        </div>

                        {stabilityCount > 0 && !imgSrc && (
                            <div className="stability-progress-container">
                                <div
                                    className="stability-progress-bar"
                                    style={{ width: `${(stabilityCount / 6) * 100}%` }}
                                ></div>
                            </div>
                        )}
                    </>
                )}
            </div>

            {!imgSrc && (
                <div className="requirements-grid" style={{ display: 'flex', gap: '10px', justifyContent: 'center', margin: '20px auto', maxWidth: '400px' }}>
                    <div className={`req-item ${verificationStatus.faceInPosition ? 'ok' : ''}`} style={{ flex: 1, display: 'flex', justifyContent: 'center', alignItems: 'center', gap: '6px' }}>
                        <Undo size={14} /> Position
                    </div>
                    <div className={`req-item ${verificationStatus.goodLighting ? 'ok' : ''}`} style={{ flex: 1, display: 'flex', justifyContent: 'center', alignItems: 'center', gap: '6px' }}>
                        <Sparkles size={14} /> Lighting
                    </div>
                    <div className={`req-item ${verificationStatus.noGlasses ? 'ok' : ''}`} style={{ flex: 1, display: 'flex', justifyContent: 'center', alignItems: 'center', gap: '6px' }}>
                        <Eye size={14} /> No Glasses
                    </div>
                </div>
            )}

            <div className="action-buttons">
                {verificationResult ? (
                    <button className="btn-primary" onClick={onBack} style={{ width: '100%' }}>
                        <Undo size={16} /> Back to Upload
                    </button>
                ) : imgSrc ? (
                    <>
                        <button className="btn-secondary" onClick={handleRetake} disabled={isCapturing}>
                            <Undo size={16} /> Retake
                        </button>
                        <button className="btn-primary" onClick={handleConfirm} disabled={isCapturing}>
                            {isCapturing ? <Loader2 size={16} className="animate-spin" /> : <Check size={16} />}
                            {isCapturing ? "Verifying..." : "Confirm & Verify"}
                        </button>
                    </>
                ) : (
                    <button className="btn-cancel" onClick={onBack}>
                        Cancel Verification
                    </button>
                )}
            </div>

            <div className="biometric-footer">
                <ShieldCheck size={16} />
                <span>AI-Powered Eye-Blink Liveness Detection</span>
            </div>
        </div>
    );
}


