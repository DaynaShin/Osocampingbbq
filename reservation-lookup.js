// 예약 조회 시스템 JavaScript (OSO Camping BBQ)
// Phase 2.4: 하이브리드 예약자 조회 시스템

let currentUser = null; // 로그인한 사용자 정보

// 페이지 로드 시 초기화
document.addEventListener('DOMContentLoaded', function() {
    setupEventListeners();
    setupMethodSwitcher();
    setupPhoneFormatter();
});

function setupEventListeners() {
    // 폼 이벤트 리스너
    const simpleLookupForm = document.getElementById('simpleLookupForm');
    const loginForm = document.getElementById('loginForm');
    const signupForm = document.getElementById('signupForm');
    
    if (simpleLookupForm) simpleLookupForm.addEventListener('submit', handleSimpleLookup);
    if (loginForm) loginForm.addEventListener('submit', handleLogin);
    if (signupForm) signupForm.addEventListener('submit', handleSignup);
    
    // 버튼 이벤트 리스너
    const closeMessageBtn = document.getElementById('closeMessage');
    const newLookupBtn = document.getElementById('newLookupBtn');
    const createAccountBtn = document.getElementById('createAccountBtn');
    const showSignupBtn = document.getElementById('showSignupBtn');
    const showLoginBtn = document.getElementById('showLoginBtn');
    const logoutBtn = document.getElementById('logoutBtn');
    
    if (closeMessageBtn) closeMessageBtn.addEventListener('click', hideMessage);
    if (newLookupBtn) newLookupBtn.addEventListener('click', resetLookup);
    if (createAccountBtn) createAccountBtn.addEventListener('click', showAccountCreation);
    if (showSignupBtn) showSignupBtn.addEventListener('click', showSignupForm);
    if (showLoginBtn) showLoginBtn.addEventListener('click', showLoginForm);
    if (logoutBtn) logoutBtn.addEventListener('click', handleLogout);
}

function setupMethodSwitcher() {
    const simpleMethodBtn = document.getElementById('simpleMethodBtn');
    const accountMethodBtn = document.getElementById('accountMethodBtn');
    const simpleLookupContainer = document.getElementById('simpleLookupContainer');
    const accountLookupContainer = document.getElementById('accountLookupContainer');
    
    if (simpleMethodBtn) {
        simpleMethodBtn.addEventListener('click', () => {
            // 간단 조회 모드
            simpleMethodBtn.classList.add('active');
            accountMethodBtn.classList.remove('active');
            simpleLookupContainer.style.display = 'block';
            accountLookupContainer.style.display = 'none';
            hideResult();
        });
    }
    
    if (accountMethodBtn) {
        accountMethodBtn.addEventListener('click', () => {
            // 계정 로그인 모드
            accountMethodBtn.classList.add('active');
            simpleMethodBtn.classList.remove('active');
            simpleLookupContainer.style.display = 'none';
            accountLookupContainer.style.display = 'block';
            hideResult();
        });
    }
}

function setupPhoneFormatter() {
    const phoneInputs = document.querySelectorAll('input[type="tel"]');
    phoneInputs.forEach(input => {
        input.addEventListener('input', function() {
            this.value = formatPhoneNumber(this.value);
        });
    });
}

function formatPhoneNumber(phone) {
    const cleaned = phone.replace(/\D/g, '');
    const match = cleaned.match(/^(\d{3})(\d{4})(\d{4})$/);
    if (match) {
        return `${match[1]}-${match[2]}-${match[3]}`;
    }
    return phone;
}

// ===============================
// 간단 조회 기능
// ===============================

async function handleSimpleLookup(event) {
    event.preventDefault();
    
    const reservationNumber = document.getElementById('reservation_number').value.trim();
    const phone = document.getElementById('lookup_phone').value.trim();
    
    if (!reservationNumber || !phone) {
        showMessage('예약번호와 전화번호를 모두 입력해주세요.', 'error');
        return;
    }
    
    // 버튼 로딩 상태
    const submitBtn = event.target.querySelector('.submit-btn');
    setButtonLoading(submitBtn, true);
    
    try {
        const result = await lookupReservationSimple(reservationNumber, phone);
        
        if (result.success && result.data && result.data.length > 0) {
            const reservation = result.data[0];
            displayReservationDetails(reservation, 'simple');
            
            // 계정 생성 버튼에 전화번호 저장
            const createAccountBtn = document.getElementById('createAccountBtn');
            if (createAccountBtn) {
                createAccountBtn.dataset.phone = phone;
                createAccountBtn.style.display = 'inline-block';
            }
        } else {
            showMessage('예약 정보를 찾을 수 없습니다. 예약번호와 전화번호를 확인해주세요.', 'error');
        }
    } catch (error) {
        console.error('예약 조회 오류:', error);
        showMessage('예약 조회 중 오류가 발생했습니다. 다시 시도해주세요.', 'error');
    } finally {
        setButtonLoading(submitBtn, false);
    }
}

async function lookupReservationSimple(reservationNumber, phone) {
    try {
        const { data, error } = await supabaseClient.rpc('lookup_reservation_simple', {
            p_reservation_number: reservationNumber,
            p_phone: phone
        });
        
        if (error) throw error;
        return { success: true, data };
    } catch (error) {
        console.error('간단 조회 오류:', error);
        return { success: false, error: error.message };
    }
}

// ===============================
// 계정 로그인 기능
// ===============================

async function handleLogin(event) {
    event.preventDefault();
    
    const phone = document.getElementById('login_phone').value.trim();
    const password = document.getElementById('login_password').value;
    
    if (!phone || !password) {
        showMessage('전화번호와 비밀번호를 모두 입력해주세요.', 'error');
        return;
    }
    
    const submitBtn = event.target.querySelector('.submit-btn');
    setButtonLoading(submitBtn, true);
    
    try {
        const result = await customerLogin(phone, password);
        
        if (result.success) {
            currentUser = result.customer;
            showMessage('로그인되었습니다.', 'success');
            showMyReservations();
        } else {
            showMessage(result.message || '로그인에 실패했습니다.', 'error');
        }
    } catch (error) {
        console.error('로그인 오류:', error);
        showMessage('로그인 중 오류가 발생했습니다.', 'error');
    } finally {
        setButtonLoading(submitBtn, false);
    }
}

async function customerLogin(phone, password) {
    try {
        const { data, error } = await supabaseClient.rpc('customer_login', {
            p_phone: phone,
            p_password: password
        });
        
        if (error) throw error;
        return data;
    } catch (error) {
        console.error('고객 로그인 오류:', error);
        return { success: false, error: error.message };
    }
}

// ===============================
// 계정 생성 기능
// ===============================

async function handleSignup(event) {
    event.preventDefault();
    
    const phone = document.getElementById('signup_phone').value.trim();
    const email = document.getElementById('signup_email').value.trim();
    const password = document.getElementById('signup_password').value;
    const confirmPassword = document.getElementById('confirm_password').value;
    
    if (!phone || !password) {
        showMessage('전화번호와 비밀번호는 필수입니다.', 'error');
        return;
    }
    
    if (password !== confirmPassword) {
        showMessage('비밀번호가 일치하지 않습니다.', 'error');
        return;
    }
    
    if (password.length < 6) {
        showMessage('비밀번호는 6자리 이상이어야 합니다.', 'error');
        return;
    }
    
    const submitBtn = event.target.querySelector('.submit-btn');
    setButtonLoading(submitBtn, true);
    
    try {
        const result = await createCustomerAccount(phone, password, email);
        
        if (result.success) {
            showMessage('계정이 생성되었습니다. 로그인해주세요.', 'success');
            showLoginForm();
            
            // 로그인 폼에 전화번호 자동 입력
            document.getElementById('login_phone').value = phone;
        } else {
            showMessage(result.message || '계정 생성에 실패했습니다.', 'error');
        }
    } catch (error) {
        console.error('계정 생성 오류:', error);
        showMessage('계정 생성 중 오류가 발생했습니다.', 'error');
    } finally {
        setButtonLoading(submitBtn, false);
    }
}

async function createCustomerAccount(phone, password, email = null) {
    try {
        const { data, error } = await supabaseClient.rpc('create_customer_account', {
            p_phone: phone,
            p_password: password,
            p_email: email
        });
        
        if (error) throw error;
        return data;
    } catch (error) {
        console.error('고객 계정 생성 오류:', error);
        return { success: false, error: error.message };
    }
}

// ===============================
// 내 예약 목록 기능
// ===============================

async function showMyReservations() {
    if (!currentUser) return;
    
    const loginFormContainer = document.getElementById('loginFormContainer');
    const signupFormContainer = document.getElementById('signupFormContainer');
    const myReservationsContainer = document.getElementById('myReservationsContainer');
    
    loginFormContainer.style.display = 'none';
    signupFormContainer.style.display = 'none';
    myReservationsContainer.style.display = 'block';
    
    try {
        const result = await getCustomerReservations(currentUser.id);
        
        if (result.success) {
            displayMyReservations(result.data);
        } else {
            showMessage('예약 내역을 불러오는 중 오류가 발생했습니다.', 'error');
        }
    } catch (error) {
        console.error('내 예약 조회 오류:', error);
        showMessage('예약 내역을 불러오는 중 오류가 발생했습니다.', 'error');
    }
}

async function getCustomerReservations(customerId) {
    try {
        const { data, error } = await supabaseClient.rpc('get_customer_reservations', {
            p_customer_id: customerId
        });
        
        if (error) throw error;
        return { success: true, data };
    } catch (error) {
        console.error('고객 예약 조회 오류:', error);
        return { success: false, error: error.message };
    }
}

function displayMyReservations(reservations) {
    const reservationsList = document.getElementById('reservationsList');
    
    if (!reservations || reservations.length === 0) {
        reservationsList.innerHTML = '<p class="no-reservations">예약 내역이 없습니다.</p>';
        return;
    }
    
    let html = '';
    reservations.forEach(reservation => {
        const statusClass = getStatusClass(reservation.status);
        const statusText = getStatusText(reservation.status);
        const reservationDate = new Date(reservation.reservation_date).toLocaleDateString('ko-KR');
        const createdDate = new Date(reservation.created_at).toLocaleDateString('ko-KR');
        
        html += `
            <div class="reservation-item ${statusClass}">
                <div class="reservation-header">
                    <div class="reservation-number">${reservation.reservation_number}</div>
                    <div class="reservation-status">${statusText}</div>
                </div>
                <div class="reservation-info">
                    <div class="info-row">
                        <span class="info-label">예약일:</span>
                        <span class="info-value">${reservationDate}</span>
                    </div>
                    <div class="info-row">
                        <span class="info-label">시설:</span>
                        <span class="info-value">${reservation.facility_name}</span>
                    </div>
                    <div class="info-row">
                        <span class="info-label">시간:</span>
                        <span class="info-value">${reservation.time_slot}</span>
                    </div>
                    <div class="info-row">
                        <span class="info-label">인원:</span>
                        <span class="info-value">${reservation.guest_count}명</span>
                    </div>
                    <div class="info-row">
                        <span class="info-label">금액:</span>
                        <span class="info-value">₩${reservation.total_amount.toLocaleString()}</span>
                    </div>
                    <div class="info-row">
                        <span class="info-label">신청일:</span>
                        <span class="info-value">${createdDate}</span>
                    </div>
                    ${reservation.special_requests ? `
                        <div class="info-row">
                            <span class="info-label">특별 요청:</span>
                            <span class="info-value">${reservation.special_requests}</span>
                        </div>
                    ` : ''}
                </div>
                ${reservation.can_modify ? `
                    <div class="reservation-actions">
                        <button type="button" class="link-btn" onclick="contactAdmin('${reservation.reservation_number}')">
                            문의하기
                        </button>
                    </div>
                ` : ''}
            </div>
        `;
    });
    
    reservationsList.innerHTML = html;
}

// ===============================
// UI 표시 함수들
// ===============================

function displayReservationDetails(reservation, source = 'simple') {
    const lookupResult = document.getElementById('lookupResult');
    const reservationDetails = document.getElementById('reservationDetails');
    
    const statusClass = getStatusClass(reservation.status);
    const statusText = getStatusText(reservation.status);
    const reservationDate = new Date(reservation.reservation_date).toLocaleDateString('ko-KR');
    const createdDate = new Date(reservation.created_at).toLocaleDateString('ko-KR');
    
    reservationDetails.innerHTML = `
        <div class="reservation-card ${statusClass}">
            <div class="reservation-header">
                <h5>예약번호: ${reservation.reservation_number}</h5>
                <div class="status-badge ${statusClass}">${statusText}</div>
            </div>
            
            <div class="reservation-info">
                <div class="info-section">
                    <h6>예약 정보</h6>
                    <div class="info-grid">
                        <div class="info-item">
                            <span class="label">예약일:</span>
                            <span class="value">${reservationDate}</span>
                        </div>
                        <div class="info-item">
                            <span class="label">시설:</span>
                            <span class="value">${reservation.facility_name}</span>
                        </div>
                        <div class="info-item">
                            <span class="label">시간:</span>
                            <span class="value">${reservation.time_slot}</span>
                        </div>
                        <div class="info-item">
                            <span class="label">인원:</span>
                            <span class="value">${reservation.guest_count}명</span>
                        </div>
                        <div class="info-item">
                            <span class="label">금액:</span>
                            <span class="value">₩${reservation.total_amount.toLocaleString()}</span>
                        </div>
                    </div>
                </div>
                
                <div class="info-section">
                    <h6>예약자 정보</h6>
                    <div class="info-grid">
                        <div class="info-item">
                            <span class="label">이름:</span>
                            <span class="value">${reservation.customer_name}</span>
                        </div>
                        <div class="info-item">
                            <span class="label">전화번호:</span>
                            <span class="value">${reservation.customer_phone}</span>
                        </div>
                        ${reservation.customer_email ? `
                            <div class="info-item">
                                <span class="label">이메일:</span>
                                <span class="value">${reservation.customer_email}</span>
                            </div>
                        ` : ''}
                        <div class="info-item">
                            <span class="label">신청일:</span>
                            <span class="value">${createdDate}</span>
                        </div>
                    </div>
                </div>
                
                ${reservation.special_requests ? `
                    <div class="info-section">
                        <h6>특별 요청사항</h6>
                        <p class="special-requests">${reservation.special_requests}</p>
                    </div>
                ` : ''}
                
                <div class="status-info">
                    ${getStatusMessage(reservation.status)}
                </div>
            </div>
        </div>
    `;
    
    lookupResult.style.display = 'block';
    lookupResult.scrollIntoView({ behavior: 'smooth', block: 'start' });
}

function getStatusClass(status) {
    switch (status) {
        case 'pending': return 'status-pending';
        case 'confirmed': return 'status-confirmed';
        case 'cancelled': return 'status-cancelled';
        case 'completed': return 'status-completed';
        default: return 'status-pending';
    }
}

function getStatusText(status) {
    switch (status) {
        case 'pending': return '승인 대기';
        case 'confirmed': return '예약 확정';
        case 'cancelled': return '취소됨';
        case 'completed': return '이용 완료';
        default: return '승인 대기';
    }
}

function getStatusMessage(status) {
    switch (status) {
        case 'pending': 
            return `
                <div class="status-message pending">
                    <p><strong>📋 승인 대기 중</strong></p>
                    <p>예약 신청이 접수되었습니다. 관리자 검토 후 확정 안내드리겠습니다.</p>
                </div>
            `;
        case 'confirmed':
            return `
                <div class="status-message confirmed">
                    <p><strong>✅ 예약 확정</strong></p>
                    <p>예약이 확정되었습니다. 예약일에 방문해 주세요.</p>
                </div>
            `;
        case 'cancelled':
            return `
                <div class="status-message cancelled">
                    <p><strong>❌ 예약 취소</strong></p>
                    <p>예약이 취소되었습니다.</p>
                </div>
            `;
        case 'completed':
            return `
                <div class="status-message completed">
                    <p><strong>🎉 이용 완료</strong></p>
                    <p>이용해 주셔서 감사합니다.</p>
                </div>
            `;
        default:
            return '';
    }
}

// ===============================
// 폼 전환 함수들
// ===============================

function showLoginForm() {
    document.getElementById('loginFormContainer').style.display = 'block';
    document.getElementById('signupFormContainer').style.display = 'none';
    document.getElementById('myReservationsContainer').style.display = 'none';
}

function showSignupForm() {
    document.getElementById('loginFormContainer').style.display = 'none';
    document.getElementById('signupFormContainer').style.display = 'block';
    document.getElementById('myReservationsContainer').style.display = 'none';
}

function showAccountCreation() {
    const createAccountBtn = document.getElementById('createAccountBtn');
    const phone = createAccountBtn.dataset.phone;
    
    // 계정 방식으로 전환
    document.getElementById('accountMethodBtn').click();
    
    // 회원가입 폼 표시 및 전화번호 자동 입력
    showSignupForm();
    if (phone) {
        document.getElementById('signup_phone').value = phone;
    }
    
    hideResult();
}

function resetLookup() {
    // 폼 초기화
    document.getElementById('simpleLookupForm').reset();
    const loginForm = document.getElementById('loginForm');
    const signupForm = document.getElementById('signupForm');
    if (loginForm) loginForm.reset();
    if (signupForm) signupForm.reset();
    
    // 결과 숨기기
    hideResult();
    
    // 간단 조회 모드로 전환
    document.getElementById('simpleMethodBtn').click();
}

function hideResult() {
    document.getElementById('lookupResult').style.display = 'none';
}

function handleLogout() {
    currentUser = null;
    showLoginForm();
    showMessage('로그아웃되었습니다.', 'success');
}

// ===============================
// 유틸리티 함수들
// ===============================

function setButtonLoading(button, isLoading) {
    const btnText = button.querySelector('.btn-text');
    const btnLoader = button.querySelector('.btn-loader');
    
    if (isLoading) {
        button.disabled = true;
        if (btnText) btnText.style.display = 'none';
        if (btnLoader) btnLoader.style.display = 'inline';
    } else {
        button.disabled = false;
        if (btnText) btnText.style.display = 'inline';
        if (btnLoader) btnLoader.style.display = 'none';
    }
}

function showMessage(message, type = 'info') {
    const messageContainer = document.getElementById('messageContainer');
    const messageContent = document.getElementById('messageContent');
    
    messageContent.textContent = message;
    messageContainer.className = `message-container ${type}`;
    messageContainer.style.display = 'block';
    
    // 3초 후 자동 숨김
    setTimeout(hideMessage, 3000);
}

function hideMessage() {
    document.getElementById('messageContainer').style.display = 'none';
}

function contactAdmin(reservationNumber) {
    showMessage(`예약번호 ${reservationNumber}에 대한 문의사항이 있으시면 관리자에게 연락해주세요.`, 'info');
}

// Supabase 함수들을 supabase-config-v2.js에 추가해야 함
window.lookupReservationSimple = lookupReservationSimple;
window.customerLogin = customerLogin;
window.createCustomerAccount = createCustomerAccount;
window.getCustomerReservations = getCustomerReservations;