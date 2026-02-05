import { useState } from "react";
import "./styles/App.css";
import KycForm from "./components/KycForm";
import Camera from "./components/Camera";
import { verifyFace } from "./services/api";
import { ToastContainer, toast } from 'react-toastify';
import 'react-toastify/dist/ReactToastify.css';

function App() {
  const [aadhaarPhoto, setAadhaarPhoto] = useState(null);
  const [aadhaarDetails, setAadhaarDetails] = useState(null);


  const capture = async (img) => {
    const blob = await fetch(img).then(res => res.blob());
    const res = await verifyFace(blob, aadhaarPhoto);
    if (res.data.verified) {
      toast.success("KYC VERIFICATION SUCCESSFUL!");
    } else {
      toast.error("KYC VERIFICATION FAILED. Please try again.");
    }
    return res.data;
  };

  return (
    <div className="App">
      <ToastContainer position="top-right" autoClose={3000} />
      <div className="app-container">
        {!aadhaarPhoto && (
          <KycForm
            onSuccess={(photo, details) => {
              setAadhaarPhoto(photo);
              setAadhaarDetails(details);
            }}
          />
        )}
        {aadhaarPhoto && (
          <Camera
            onCapture={capture}
            details={aadhaarDetails}
            onBack={() => setAadhaarPhoto(null)}
          />
        )}
      </div>

    </div>
  );
}

export default App;

