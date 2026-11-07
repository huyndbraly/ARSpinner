import Foundation

/// Unique keys identifying physics and simulation parameters for interactive help.
enum PhysicsParameterKey: String, CaseIterable, Identifiable, Sendable {
    case presets
    case frictionType
    case viscousDamping
    case coulombFriction
    case totalMass
    case momentOfInertia
    case maxSafeSpeed
    case spinMode
    case audioEffects
    
    var id: String { rawValue }
}

/// Structured explanation model presenting physics concepts in accessible everyday language.
struct PhysicsParameterInfo: Identifiable, Sendable {
    let id: String
    let title: String
    let currentValue: String
    let whatIsIt: String
    let howItAffects: String
    let whenIncreased: String
    let whenDecreased: String
    let currentValueMeaning: String
    
    static func info(
        for key: PhysicsParameterKey,
        language: AppLanguage,
        currentValueString: String
    ) -> PhysicsParameterInfo {
        switch language {
        case .vi:
            return vietnameseInfo(for: key, currentValue: currentValueString)
        case .en:
            return englishInfo(for: key, currentValue: currentValueString)
        }
    }
    
    // MARK: - Vietnamese Explanations
    
    private static func vietnameseInfo(for key: PhysicsParameterKey, currentValue: String) -> PhysicsParameterInfo {
        switch key {
        case .presets:
            return PhysicsParameterInfo(
                id: key.rawValue,
                title: "Bộ cấu hình sẵn",
                currentValue: currentValue,
                whatIsIt: "Tập hợp các thông số vật lý và vòng bi được tinh chỉnh sẵn mô phỏng các dòng fidget spinner thực tế phổ biến.",
                howItAffects: "Thay đổi đồng thời loại vòng bi, hệ số ma sát, khối lượng và độ cản của con quay chỉ với một chạm.",
                whenIncreased: "Chọn 'Tốc độ cao' sử dụng vòng bi Full Ceramic siêu trơn giúp quay lâu nhất; 'Đồng khối nặng' tăng khối lượng tạo cảm giác đầm tay.",
                whenDecreased: "Chọn 'Tiêu chuẩn' để trải nghiệm sự cân bằng giữa tốc độ và thời gian quay tự nhiên.",
                currentValueMeaning: "Bạn đang sử dụng cấu hình: \(currentValue)."
            )
            
        case .frictionType:
            return PhysicsParameterInfo(
                id: key.rawValue,
                title: "Loại ma sát vòng bi",
                currentValue: currentValue,
                whatIsIt: "Mô hình toán học mô phỏng các lực cản đối kháng chuyển động quay trong vòng bi cơ học.",
                howItAffects: "Quyết định cách con quay giảm tốc theo thời gian từ tốc độ cao cho đến khi dừng hẳn.",
                whenIncreased: "Mô hình 'Kết hợp' mô phỏng cả ma sát trượt của các viên bi và sức cản của dầu bôi trơn/không khí.",
                whenDecreased: "Chọn 'Chỉ Coulomb' nếu muốn mô phỏng vòng bi khô; chọn 'Chỉ Nhớt' nếu muốn lực cản tăng mạnh khi quay nhanh.",
                currentValueMeaning: "Đang áp dụng mô hình ma sát: \(currentValue)."
            )
            
        case .viscousDamping:
            return PhysicsParameterInfo(
                id: key.rawValue,
                title: "Cản nhớt (Không khí & Dầu mỡ)",
                currentValue: currentValue,
                whatIsIt: "Thông số mô phỏng lực cản khí động học của không khí xung quanh các cánh quay và độ nhớt của dầu mỡ trong vòng bi.",
                howItAffects: "Lực cản này tỉ lệ thuận với tốc độ quay. Quay càng nhanh thì lực cản này càng lớn.",
                whenIncreased: "Con quay sẽ mất tốc độ rất nhanh khi đang quay ở tốc độ cao, nhưng khi quay chậm thì lực cản này giảm đi.",
                whenDecreased: "Mô phỏng con quay trong môi trường ít cản hoặc vòng bi gốm không dùng dầu, duy trì tốc độ đỉnh lâu hơn.",
                currentValueMeaning: "Hệ số cản nhớt hiện tại: \(currentValue)."
            )
            
        case .coulombFriction:
            return PhysicsParameterInfo(
                id: key.rawValue,
                title: "Ma sát khô Coulomb vòng bi",
                currentValue: currentValue,
                whatIsIt: "Mô phỏng lực ma sát cơ học tiếp xúc liên tục giữa các viên bi gốm/thép và rãnh trượt bên trong vòng bi.",
                howItAffects: "Tạo ra một lực cản đều đặn ở mọi tốc độ và đóng vai trò quyết định giúp con quay dừng lại dứt khoát khi tốc độ xuống thấp.",
                whenIncreased: "Vòng bi có độ ma sát lớn hơn, con quay nhanh chóng chậm lại và dừng hẳn sớm hơn.",
                whenDecreased: "Vòng bi quay siêu êm và trơn tru, khi gần dừng vẫn tiếp tục quay nhẹ nhàng thêm một lúc lâu.",
                currentValueMeaning: "Hệ số ma sát khô hiện tại: \(currentValue)."
            )
            
        case .totalMass:
            return PhysicsParameterInfo(
                id: key.rawValue,
                title: "Tổng khối lượng spinner",
                currentValue: currentValue,
                whatIsIt: "Khối lượng tổng thể phân bố trên toàn bộ con quay (bao gồm khung cánh, ổ bi trung tâm và các tạ kim loại ở cánh).",
                howItAffects: "Khối lượng tác động trực tiếp lên quán tính và cảm giác nặng nhẹ khi người dùng vuốt lực.",
                whenIncreased: "Con quay nặng hơn, đòi hỏi lực vuốt mạnh hơn để đạt tốc độ cao, nhưng có trớn quay đầm và giữ tốc độ tốt hơn.",
                whenDecreased: "Con quay nhẹ hơn, phản hồi nhạy bén và vọt lên tốc độ cao chỉ với lực vuốt nhẹ.",
                currentValueMeaning: "Khối lượng hiện tại: \(currentValue)."
            )
            
        case .momentOfInertia:
            return PhysicsParameterInfo(
                id: key.rawValue,
                title: "Mô men quán tính (I)",
                currentValue: currentValue,
                whatIsIt: "Đại diện cho mức độ khó thay đổi tốc độ quay của con quay quanh trục. Được tính toán tự động từ khối lượng, đường kính cánh và vị trí các tạ đồng.",
                howItAffects: "Khối lượng phân bố càng xa trục quay (ở đầu 3 cánh) thì mô men quán tính càng lớn.",
                whenIncreased: "Con quay có xu hướng bảo toàn trạng thái quay mạnh mẽ hơn; khó tăng tốc hơn với cùng một lực nhưng cũng khó bị dừng lại hơn.",
                whenDecreased: "Con quay tăng giảm tốc rất nhạy bén, tốc độ phản ứng tức thì với từng cử chỉ vuốt.",
                currentValueMeaning: "Mô men quán tính tính toán tự động: \(currentValue)."
            )
            
        case .maxSafeSpeed:
            return PhysicsParameterInfo(
                id: key.rawValue,
                title: "Tốc độ góc an toàn",
                currentValue: currentValue,
                whatIsIt: "Giới hạn trần tốc độ quay tối đa được phép trong mô phỏng số học.",
                howItAffects: "Đảm bảo hình ảnh quay mượt mà, tránh lỗi số học và tránh hiện tượng ảo ảnh quang học (stroboscopic aliasing) khi hiển thị trên màn hình.",
                whenIncreased: "Cho phép đạt được số vòng quay mỗi phút (RPM) cao hơn nếu người dùng vuốt thật mạnh.",
                whenDecreased: "Giữ con quay ở tốc độ quan sát vừa phải, dễ nhìn rõ chi tiết chuyển động của từng cánh.",
                currentValueMeaning: "Giới hạn tốc độ trần: \(currentValue)."
            )
            
        case .spinMode:
            return PhysicsParameterInfo(
                id: key.rawValue,
                title: "Chế độ quay (Quán tính / Tăng tốc)",
                currentValue: currentValue,
                whatIsIt: "Lựa chọn phương thức truyền lực vật lý khi người dùng thực hiện thao tác vuốt trên con quay.",
                howItAffects: "Chế độ 'Quán tính' mô phỏng tự nhiên từng cú búng ngón tay; chế độ 'Tăng tốc liên tục' cho phép vuốt liên tục để cộng dồn tốc độ lên tới 2.000 RPM.",
                whenIncreased: "Chuyển sang 'Tăng tốc liên tục' để thỏa sức vuốt dồn dập nhiều lần và theo dõi con quay tăng tốc đến giới hạn 2.000 RPM.",
                whenDecreased: "Chuyển sang 'Quán tính' để tận hưởng sự êm đềm, chân thực của chuyển động quay tự do và ma sát tự nhiên.",
                currentValueMeaning: "Chế độ tương tác hiện tại: \(currentValue)."
            )
            
        case .audioEffects:
            return PhysicsParameterInfo(
                id: key.rawValue,
                title: "Âm thanh vòng bi",
                currentValue: currentValue,
                whatIsIt: "Bộ phát âm thanh cơ học thời gian thực mô phỏng tiếng kim loại và tiếng gió rít khi các viên bi quay trong ổ đỡ.",
                howItAffects: "Tăng tính chân thực đa giác quan: âm trầm êm ái ở tốc độ thấp và chuyển sang tiếng rít cơ học cao vút khi quay nhanh.",
                whenIncreased: "Tăng âm lượng giúp nghe rõ từng nhịp quay và cảm nhận độ trơn tru của ổ bi.",
                whenDecreased: "Giảm âm lượng hoặc tắt âm nếu bạn muốn tập trung vào trải nghiệm thị giác tĩnh lặng.",
                currentValueMeaning: "Trạng thái âm thanh: \(currentValue)."
            )
        }
    }
    
    // MARK: - English Explanations
    
    private static func englishInfo(for key: PhysicsParameterKey, currentValue: String) -> PhysicsParameterInfo {
        switch key {
        case .presets:
            return PhysicsParameterInfo(
                id: key.rawValue,
                title: "Spinner Presets",
                currentValue: currentValue,
                whatIsIt: "Curated collections of physical mass, bearing friction, and inertia parameters modeling popular real-world fidget spinners.",
                howItAffects: "Instantly reconfigures the spinner's weight, bearing type, and deceleration behavior in one tap.",
                whenIncreased: "Selecting 'High Speed' equips an ultra-low-friction Full Ceramic bearing for longest spins; 'Heavy Brass' increases mass for a weighty, deliberate feel.",
                whenDecreased: "Selecting 'Standard' provides a balanced hybrid ceramic feel with smooth and realistic spin times (~45s).",
                currentValueMeaning: "Active preset: \(currentValue)."
            )
            
        case .frictionType:
            return PhysicsParameterInfo(
                id: key.rawValue,
                title: "Bearing Friction Model",
                currentValue: currentValue,
                whatIsIt: "The mathematical physics formulation modeling resistive forces inside the central ball bearing.",
                howItAffects: "Determines the shape of the deceleration curve from high rotational speed down to rest.",
                whenIncreased: "'Combined' pairs velocity-proportional drag with dry ball contact friction for maximum authenticity.",
                whenDecreased: "'Coulomb Only' simulates a dry bearing; 'Viscous Only' simulates fluid-dominant aerodynamic drag.",
                currentValueMeaning: "Active model: \(currentValue)."
            )
            
        case .viscousDamping:
            return PhysicsParameterInfo(
                id: key.rawValue,
                title: "Viscous Damping (Air & Lubricant)",
                currentValue: currentValue,
                whatIsIt: "Coefficient modeling aerodynamic atmospheric drag on spinner wings and lubricant shear inside the race.",
                howItAffects: "Produces opposing torque directly proportional to angular speed: higher speeds experience exponentially greater resistance.",
                whenIncreased: "The spinner sheds peak rotational speed much faster when spinning at high RPM.",
                whenDecreased: "Simulates zero-oil ceramic bearings in low-drag air, preserving peak velocity longer.",
                currentValueMeaning: "Current coefficient: \(currentValue)."
            )
            
        case .coulombFriction:
            return PhysicsParameterInfo(
                id: key.rawValue,
                title: "Dry Coulomb Bearing Friction",
                currentValue: currentValue,
                whatIsIt: "Coefficient modeling constant mechanical contact drag between rotating bearing balls and the raceway.",
                howItAffects: "Applies a steady resistance regardless of speed and governs how cleanly the spinner comes to a complete rest.",
                whenIncreased: "The bearing feels tighter; motion ceases sooner as velocity drops into the low RPM range.",
                whenDecreased: "The bearing glides with high precision, slowly rolling for an extended duration before stopping.",
                currentValueMeaning: "Current coefficient: \(currentValue)."
            )
            
        case .totalMass:
            return PhysicsParameterInfo(
                id: key.rawValue,
                title: "Total Spinner Mass",
                currentValue: currentValue,
                whatIsIt: "Overall physical mass of the spinner, including the central hub, wing body, and outer counterweights.",
                howItAffects: "Directly affects rotational inertia and the finger effort required to induce spin acceleration.",
                whenIncreased: "Heavier spinner requires more swipe momentum to accelerate, but carries richer rotational momentum.",
                whenDecreased: "Lighter spinner responds effortlessly to gentle flicks and rapidly surges in RPM.",
                currentValueMeaning: "Current mass: \(currentValue)."
            )
            
        case .momentOfInertia:
            return PhysicsParameterInfo(
                id: key.rawValue,
                title: "Moment of Inertia (I)",
                currentValue: currentValue,
                whatIsIt: "A measure of the spinner's resistance to angular acceleration around its spin axis. Automatically computed from geometry, diameter, and weight distribution.",
                howItAffects: "Mass distributed further from the center (at wing tips) dramatically increases rotational inertia.",
                whenIncreased: "Spinner resists sudden speed changes; harder to accelerate with one swipe, but resists small drag forces.",
                whenDecreased: "Spinner accelerates and decelerates quickly with immediate sensitivity to touch.",
                currentValueMeaning: "Computed moment of inertia: \(currentValue)."
            )
            
        case .maxSafeSpeed:
            return PhysicsParameterInfo(
                id: key.rawValue,
                title: "Max Safe Angular Velocity",
                currentValue: currentValue,
                whatIsIt: "Numerical ceiling on rotational velocity to guarantee simulation stability and clear visual rendering.",
                howItAffects: "Prevents stroboscopic optical illusions and numerical divergence during extreme gestures.",
                whenIncreased: "Permits higher RPM ceilings for vigorous physical swipes.",
                whenDecreased: "Restricts rotation to lower, highly observable speeds.",
                currentValueMeaning: "Maximum velocity limit: \(currentValue)."
            )
            
        case .spinMode:
            return PhysicsParameterInfo(
                id: key.rawValue,
                title: "Spin Mode (Natural / Continuous)",
                currentValue: currentValue,
                whatIsIt: "The interaction paradigm governing how touch swipe impulses are transferred to the spinner.",
                howItAffects: "'Natural Spin' treats each swipe as an isolated physical flick; 'Continuous Spin' stacks successive swipes up to 2,000 RPM.",
                whenIncreased: "Select 'Continuous Spin' to repeatedly swipe and pump the spinner up to maximum speed (2,000 RPM).",
                whenDecreased: "Select 'Natural Spin' for pure single-flick simulation with authentic bearing spindown.",
                currentValueMeaning: "Active spin mode: \(currentValue)."
            )
            
        case .audioEffects:
            return PhysicsParameterInfo(
                id: key.rawValue,
                title: "Bearing Sound Effects",
                currentValue: currentValue,
                whatIsIt: "Procedural mechanical audio engine simulating real-time ball bearing raceway acoustics.",
                howItAffects: "Modulates pitch and volume dynamically with RPM: soft hum at low speed, rising to a crisp mechanical whir.",
                whenIncreased: "Higher volume enhances tactile and multisensory feedback.",
                whenDecreased: "Lower volume or mute allows a quiet, visual-focused experience.",
                currentValueMeaning: "Audio state: \(currentValue)."
            )
        }
    }
}

