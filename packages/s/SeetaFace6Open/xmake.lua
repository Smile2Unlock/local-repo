package("SeetaFace6Open")
    set_description("SeetaFace6Open")

    on_load(function (package)
        package:set("installdir", path.join(os.scriptdir(), package:plat()))
    end)

    on_fetch(function (package)
        local result = {}
        result.links = {
            "SeetaAgePredictor600","SeetaAgePredictor600d",
            "SeetaEyeStateDetector200","SeetaEyeStateDetector200d",
            "SeetaFaceAntiSpoofingX600","SeetaFaceAntiSpoofingX600d",
            "SeetaFaceDetector600","SeetaFaceDetector600d",
            "SeetaFaceLandmarker600","SeetaFaceLandmarker600d",
            "SeetaFaceRecognizer610","SeetaFaceRecognizer610d",
            "SeetaFaceTracking600","SeetaFaceTracking600d",
            "SeetaGenderPredictor600","SeetaGenderPredictor600d",
            "SeetaMaskDetector200","SeetaMaskDetector200d",
            "SeetaPoseEstimation600","SeetaPoseEstimation600d",
            "SeetaQualityAssessor300","SeetaQualityAssessor300d"
        }
        result.linkdirs = package:installdir("lib")
        result.includedirs = package:installdir("include")
        return result
    end)