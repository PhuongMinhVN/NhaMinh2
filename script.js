document.addEventListener('DOMContentLoaded', () => {
    const form = document.getElementById('supabase-auth-form');
    const projectUrlInput = document.getElementById('projectUrl');
    const apiKeyInput = document.getElementById('apiKey');
    const toggleKeyBtn = document.getElementById('toggleKey');
    const statusMessage = document.getElementById('statusMessage');
    const saveLocallyCheckbox = document.getElementById('saveLocally');

    // --- INIT ---
    // Check local storage for previous session
    const savedUrl = localStorage.getItem('family_app_url');
    // Security Note: In a real app, use encryption or secure cookie.
    const savedKey = sessionStorage.getItem('family_app_key') || localStorage.getItem('family_app_key_enc');

    if (savedUrl) projectUrlInput.value = savedUrl;
    // We intentionally don't autofill the key visually for safety unless the user clicks something,
    // but for UX in this prototype we can leave it empty to force re-entry or fill if really needed.
    // Let's just check if we have them to potentially skip login? No, let's let them enter.

    // --- EVENT LISTENERS ---

    // 1. Password Visibility
    toggleKeyBtn.addEventListener('click', () => {
        const type = apiKeyInput.getAttribute('type') === 'password' ? 'text' : 'password';
        apiKeyInput.setAttribute('type', type);

        const eyeIcon = toggleKeyBtn.querySelector('svg');
        if (type === 'text') {
            // Open Eye (Slashing it actually means 'hide' usually, but here we just swap icons)
            eyeIcon.innerHTML = '<path stroke-linecap="round" stroke-linejoin="round" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.88 9.88l-3.29-3.29m7.532 7.532l3.29 3.29M3 3l3.59 3.59m0 0A9.953 9.953 0 0112 5c4.478 0 8.268 2.943 9.543 7a10.025 10.025 0 01-4.132 5.411m0 0L21 21" />';
        } else {
            // Closed/Normal Eye
            eyeIcon.innerHTML = '<path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" /><path stroke-linecap="round" stroke-linejoin="round" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />';
        }
    });

    // 2. Form Submit
    form.addEventListener('submit', (e) => {
        e.preventDefault();

        const url = projectUrlInput.value.trim();
        const key = apiKeyInput.value.trim();
        const saveLocally = saveLocallyCheckbox.checked;

        if (!url || !key) {
            showStatus('Vui lòng nhập đầy đủ thông tin kết nối.', 'error');
            return;
        }

        if (!url.startsWith('https://')) {
            showStatus('URL không hợp lệ. Phải bắt đầu bằng https://', 'error');
            return;
        }

        // Mock Loading
        const btnOriginalText = document.querySelector('.btn-primary span').innerText;
        const btn = document.querySelector('.btn-primary');
        btn.querySelector('span').innerText = 'Đang xác thực...';
        btn.disabled = true;

        setTimeout(() => {
            // Restore button
            btn.querySelector('span').innerText = btnOriginalText;
            btn.disabled = false;

            // Save Logic
            try {
                if (saveLocally) {
                    localStorage.setItem('family_app_url', url);
                    localStorage.setItem('family_app_key_enc', key);
                } else {
                    sessionStorage.setItem('family_app_url', url);
                    sessionStorage.setItem('family_app_key', key);
                    // Clear permanent storage if user opts out
                    localStorage.removeItem('family_app_url');
                    localStorage.removeItem('family_app_key_enc');
                }

                showStatus('Kết nối thành công! Đang vào hệ thống...', 'success');
                console.log('App Initialized for context: ', url);

                // Here we would normally redirect to dashboard.html
                // window.location.href = 'dashboard.html';

            } catch (err) {
                showStatus('Lỗi lưu trữ cục bộ.', 'error');
                console.error(err);
            }
        }, 1500); // Fake network delay
    });

    function showStatus(msg, type) {
        statusMessage.textContent = msg;
        statusMessage.className = `status-message ${type}`;

        if (type === 'error') {
            const card = document.querySelector('.card');
            card.animate([
                { transform: 'translateX(0)' },
                { transform: 'translateX(-10px)' },
                { transform: 'translateX(10px)' },
                { transform: 'translateX(0)' }
            ], { duration: 400 });
        }
    }
});
