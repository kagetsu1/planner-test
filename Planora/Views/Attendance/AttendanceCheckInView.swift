import SwiftUI
import AVFoundation

/// Attendance check-in view with passcode input and QR scanning
struct AttendanceCheckInView: View {
    let session: AttendanceSession
    let onSuccess: () -> Void
    let onCancel: () -> Void
    
    @StateObject private var attendanceService = AttendanceService()
    @State private var passcode = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var showingQRScanner = false
    @State private var isSuccessful = false
    
    @FocusState private var isPasscodeFieldFocused: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: UITheme.Spacing.xl) {
                // Header
                headerSection
                
                // Session info
                sessionInfoSection
                
                // Input methods
                inputMethodsSection
                
                Spacer()
                
                // Submit button
                submitButton
            }
            .padding()
            .background(UITheme.Colors.background)
            .navigationTitle("Check In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", action: onCancel)
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                }
            }
            .sheet(isPresented: $showingQRScanner) {
                QRScannerView { qrResult in
                    handleQRScan(qrResult)
                } onCancel: {
                    showingQRScanner = false
                }
            }
            .onChange(of: isSuccessful) { success in
                if success {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        onSuccess()
                    }
                }
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: UITheme.Spacing.md) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(isSuccessful ? UITheme.Colors.success : UITheme.Colors.primary)
                .scaleEffect(isSuccessful ? 1.2 : 1.0)
                .animation(UITheme.Animation.standard, value: isSuccessful)
            
            Text(isSuccessful ? "Checked In!" : "Attendance Check-In")
                .font(UITheme.Typography.title1)
                .foregroundColor(UITheme.Colors.primaryText)
                .multilineTextAlignment(.center)
            
            if isSuccessful {
                Text("Your attendance has been recorded")
                    .font(UITheme.Typography.body)
                    .foregroundColor(UITheme.Colors.secondaryText)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    private var sessionInfoSection: some View {
        VStack(alignment: .leading, spacing: UITheme.Spacing.md) {
            Text("Session Details")
                .font(UITheme.Typography.title3)
                .fontWeight(.semibold)
                .foregroundColor(UITheme.Colors.primaryText)
            
            VStack(alignment: .leading, spacing: UITheme.Spacing.sm) {
                if let courseId = session.courseId {
                    infoRow("Course", courseId)
                }
                
                if let room = session.room {
                    infoRow("Room", room)
                }
                
                if let start = session.start {
                    infoRow("Time", formatSessionTime(start, end: session.end))
                }
                
                infoRow("Status", session.requiresPasscode ? "Requires Passcode" : "Open Check-in")
            }
        }
        .themeCard()
    }
    
    private var inputMethodsSection: some View {
        VStack(spacing: UITheme.Spacing.lg) {
            if !isSuccessful {
                // Passcode input
                passcodeInputSection
                
                // QR Code scanner
                qrScannerSection
            }
        }
    }
    
    private var passcodeInputSection: some View {
        VStack(alignment: .leading, spacing: UITheme.Spacing.md) {
            Text("Enter Passcode")
                .font(UITheme.Typography.title3)
                .fontWeight(.semibold)
                .foregroundColor(UITheme.Colors.primaryText)
            
            VStack(spacing: UITheme.Spacing.sm) {
                TextField("Passcode", text: $passcode)
                    .textFieldStyle(.roundedBorder)
                    .font(UITheme.Typography.body)
                    .focused($isPasscodeFieldFocused)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .disabled(isSubmitting)
                
                if session.requiresPasscode {
                    Text("This session requires a passcode from your instructor")
                        .font(UITheme.Typography.caption)
                        .foregroundColor(UITheme.Colors.secondaryText)
                }
            }
        }
        .themeCard()
    }
    
    private var qrScannerSection: some View {
        VStack(alignment: .leading, spacing: UITheme.Spacing.md) {
            Text("Scan QR Code")
                .font(UITheme.Typography.title3)
                .fontWeight(.semibold)
                .foregroundColor(UITheme.Colors.primaryText)
            
            Button(action: {
                showingQRScanner = true
            }) {
                HStack(spacing: UITheme.Spacing.md) {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.title2)
                        .foregroundColor(UITheme.Colors.primary)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Scan QR Code")
                            .font(UITheme.Typography.body)
                            .fontWeight(.medium)
                            .foregroundColor(UITheme.Colors.primaryText)
                        
                        Text("Use your camera to scan the attendance QR code")
                            .font(UITheme.Typography.caption)
                            .foregroundColor(UITheme.Colors.secondaryText)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(UITheme.Colors.tertiary)
                }
                .padding()
            }
            .disabled(isSubmitting)
        }
        .themeCard()
    }
    
    private var submitButton: some View {
        Button(action: submitAttendance) {
            HStack {
                if isSubmitting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                    
                    Text("Checking In...")
                        .font(UITheme.Typography.buttonText)
                        .foregroundColor(.white)
                } else {
                    Text("Check In")
                        .font(UITheme.Typography.buttonText)
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(UITheme.Colors.primary)
            .clipShape(RoundedRectangle(cornerRadius: UITheme.CornerRadius.button))
        }
        .disabled(isSubmitting || isSuccessful || (!session.requiresPasscode && passcode.isEmpty))
        .opacity(isSuccessful ? 0 : 1)
        .animation(UITheme.Animation.standard, value: isSuccessful)
    }
    
    // MARK: - Helper Views
    
    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(UITheme.Typography.caption)
                .foregroundColor(UITheme.Colors.secondaryText)
            
            Spacer()
            
            Text(value)
                .font(UITheme.Typography.caption)
                .fontWeight(.medium)
                .foregroundColor(UITheme.Colors.primaryText)
        }
    }
    
    // MARK: - Actions
    
    private func submitAttendance() {
        guard !isSubmitting else { return }
        
        isSubmitting = true
        errorMessage = nil
        
        let passcodeToSubmit = passcode.isEmpty ? nil : passcode
        
                    _Concurrency.Task {
            do {
                let success = try await attendanceService.submitAttendance(
                    for: session,
                    passcode: passcodeToSubmit
                )
                
                await MainActor.run {
                    isSubmitting = false
                    
                    if success {
                        isSuccessful = true
                        let successFeedback = UINotificationFeedbackGenerator()
                        successFeedback.notificationOccurred(.success)
                    } else {
                        errorMessage = "Check-in failed. Please try again."
                        let errorFeedback = UINotificationFeedbackGenerator()
                        errorFeedback.notificationOccurred(.error)
                    }
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = error.localizedDescription
                    
                    let errorFeedback = UINotificationFeedbackGenerator()
                    errorFeedback.notificationOccurred(.error)
                }
            }
        }
    }
    
    private func handleQRScan(_ result: String) {
        showingQRScanner = false
        
        if let qrData = attendanceService.parseQRCode(result) {
            // Check if this QR code matches the current session
            if qrData.sessionId == session.id {
                passcode = qrData.passcode ?? ""
                isPasscodeFieldFocused = false
                
                // Auto-submit if we have all required info
                if !session.requiresPasscode || !passcode.isEmpty {
                    submitAttendance()
                }
            } else {
                errorMessage = "This QR code is for a different session."
            }
        } else {
            errorMessage = "Invalid QR code format."
        }
    }
    
    private func formatSessionTime(_ start: Date, end: Date?) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        
        let startString = formatter.string(from: start)
        
        if let end = end {
            let endString = formatter.string(from: end)
            return "\(startString) - \(endString)"
        } else {
            return startString
        }
    }
}

// MARK: - QR Scanner View

struct QRScannerView: View {
    let onScanSuccess: (String) -> Void
    let onCancel: () -> Void
    
    @StateObject private var qrScanner = QRCodeScanner()
    
    var body: some View {
        NavigationView {
            ZStack {
                // Camera preview
                QRCodeScannerViewRepresentable(scanner: qrScanner) { result in
                    onScanSuccess(result)
                }
                .ignoresSafeArea()
                
                // Overlay
                scannerOverlay
            }
            .navigationTitle("Scan QR Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", action: onCancel)
                }
            }
        }
    }
    
    private var scannerOverlay: some View {
        VStack {
            Text("Position the QR code within the frame")
                .font(UITheme.Typography.body)
                .foregroundColor(.white)
                .padding()
                .background(Color.black.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: UITheme.CornerRadius.medium))
            
            Spacer()
            
            // Scanning frame
            RoundedRectangle(cornerRadius: UITheme.CornerRadius.large)
                .stroke(Color.white, lineWidth: 3)
                .frame(width: 250, height: 250)
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - QR Code Scanner

class QRCodeScanner: NSObject, ObservableObject {
    @Published var isScanning = false
    
    private var captureSession = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    override init() {
        super.init()
        setupCamera()
    }
    
    private func setupCamera() {
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return }
        
        do {
            let videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
            
            if captureSession.canAddInput(videoInput) {
                captureSession.addInput(videoInput)
            }
            
            let metadataOutput = AVCaptureMetadataOutput()
            
            if captureSession.canAddOutput(metadataOutput) {
                captureSession.addOutput(metadataOutput)
                metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
                metadataOutput.metadataObjectTypes = [.qr]
            }
            
        } catch {
            print("Error setting up camera: \(error)")
        }
    }
    
    func startScanning() {
        DispatchQueue.global(qos: .background).async {
            self.captureSession.startRunning()
            DispatchQueue.main.async {
                self.isScanning = true
            }
        }
    }
    
    func stopScanning() {
        captureSession.stopRunning()
        isScanning = false
    }
    
    func getPreviewLayer() -> AVCaptureVideoPreviewLayer {
        if previewLayer == nil {
            previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            previewLayer?.videoGravity = .resizeAspectFill
        }
        return previewLayer!
    }
}

extension QRCodeScanner: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
            guard let stringValue = readableObject.stringValue else { return }
            
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            
            NotificationCenter.default.post(
                name: .qrCodeScanned,
                object: nil,
                userInfo: ["code": stringValue]
            )
        }
    }
}

// MARK: - UIViewRepresentable for QR Scanner

struct QRCodeScannerViewRepresentable: UIViewRepresentable {
    let scanner: QRCodeScanner
    let onScanSuccess: (String) -> Void
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        
        let previewLayer = scanner.getPreviewLayer()
        previewLayer.frame = view.layer.bounds
        view.layer.addSublayer(previewLayer)
        
        scanner.startScanning()
        
        // Listen for QR code scan notifications
        NotificationCenter.default.addObserver(
            forName: .qrCodeScanned,
            object: nil,
            queue: .main
        ) { notification in
            if let code = notification.userInfo?["code"] as? String {
                onScanSuccess(code)
            }
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Update if needed
    }
    
    static func dismantleUIView(_ uiView: UIView, coordinator: ()) {
        NotificationCenter.default.removeObserver(uiView, name: .qrCodeScanned, object: nil)
    }
}

// MARK: - Notification Extension

extension Notification.Name {
    static let qrCodeScanned = Notification.Name("qrCodeScanned")
}

// MARK: - Preview Support

#if DEBUG
extension AttendanceSession {
    static var sampleSession: AttendanceSession {
        let session = AttendanceSession()
        session.id = 123456
        session.courseId = "CS101"
        session.start = Date()
        session.end = Date().addingTimeInterval(3600)
        session.room = "Room 205"
        session.requiresPasscode = true
        session.status = "Open"
        return session
    }
}

struct AttendanceCheckInView_Previews: PreviewProvider {
    static var previews: some View {
        AttendanceCheckInView(
            session: .sampleSession,
            onSuccess: { print("Success") },
            onCancel: { print("Cancel") }
        )
        
        AttendanceCheckInView(
            session: .sampleSession,
            onSuccess: { print("Success") },
            onCancel: { print("Cancel") }
        )
        .preferredColorScheme(.dark)
    }
}
#endif
