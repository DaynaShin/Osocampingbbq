// 페이지 로드 시 초기화
document.addEventListener('DOMContentLoaded', function() {
    initializeForm();
    setupEventListeners();
    setMinDate();
});

// 폼 초기화
function initializeForm() {
    const form = document.getElementById('reservationForm');
    const submitBtn = document.getElementById('submitBtn');
    
    // 폼 리셋
    form.reset();
    
    // 버튼 상태 초기화
    resetSubmitButton();
}

// 이벤트 리스너 설정
function setupEventListeners() {
    const form = document.getElementById('reservationForm');
    const closeMessageBtn = document.getElementById('closeMessage');
    
    // 폼 제출 이벤트
    form.addEventListener('submit', handleFormSubmit);
    
    // 메시지 닫기 버튼
    closeMessageBtn.addEventListener('click', hideMessage);
    
    // 전화번호 입력 포맷팅
    const phoneInput = document.getElementById('phone');
    phoneInput.addEventListener('input', formatPhoneNumber);
    
    // 실시간 유효성 검사
    const requiredFields = form.querySelectorAll('input[required], select[required]');
    requiredFields.forEach(field => {
        field.addEventListener('blur', validateField);
    });
}

// 최소 날짜 설정 (오늘부터 선택 가능)
function setMinDate() {
    const dateInput = document.getElementById('reservation_date');
    const today = new Date().toISOString().split('T')[0];
    dateInput.min = today;
}

// 폼 제출 처리
async function handleFormSubmit(event) {
    event.preventDefault();
    
    const form = event.target;
    const formData = new FormData(form);
    
    // 유효성 검사
    if (!validateForm(form)) {
        return;
    }
    
    // 로딩 상태 시작
    setLoadingState(true);
    
    try {
        // 폼 데이터를 객체로 변환
        const reservationData = {
            name: formData.get('name').trim(),
            phone: formData.get('phone').trim(),
            email: formData.get('email')?.trim() || null,
            reservation_date: formData.get('reservation_date'),
            reservation_time: formData.get('reservation_time'),
            service_type: formData.get('service_type') || null,
            message: formData.get('message')?.trim() || null
        };
        
        // 시간 중복 체크
        const isDuplicate = await checkTimeConflict(reservationData.reservation_date, reservationData.reservation_time);
        if (isDuplicate) {
            showMessage('해당 시간에 이미 예약이 있습니다. 다른 시간을 선택해 주세요.', 'error');
            setLoadingState(false);
            return;
        }
        
        // Supabase에 데이터 저장
        const result = await createReservation(reservationData);
        
        if (result.success) {
            showMessage('예약이 성공적으로 신청되었습니다!', 'success');
            form.reset();
            setMinDate(); // 날짜 최소값 다시 설정
        } else {
            throw new Error(result.error || '예약 신청 중 오류가 발생했습니다.');
        }
        
    } catch (error) {
        console.error('예약 신청 오류:', error);
        showMessage(error.message || '예약 신청 중 오류가 발생했습니다.', 'error');
    } finally {
        setLoadingState(false);
    }
}

// 시간 중복 체크
async function checkTimeConflict(date, time) {
    try {
        const result = await getReservationsByDate(date);
        if (result.success && result.data) {
            return result.data.some(reservation => reservation.reservation_time === time);
        }
        return false;
    } catch (error) {
        console.error('시간 중복 체크 오류:', error);
        return false;
    }
}

// 폼 유효성 검사
function validateForm(form) {
    let isValid = true;
    const requiredFields = form.querySelectorAll('input[required], select[required]');
    
    requiredFields.forEach(field => {
        if (!validateField({ target: field })) {
            isValid = false;
        }
    });
    
    // 이메일 유효성 검사
    const emailField = document.getElementById('email');
    if (emailField.value && !isValidEmail(emailField.value)) {
        showFieldError(emailField, '올바른 이메일 주소를 입력해주세요.');
        isValid = false;
    }
    
    // 전화번호 유효성 검사
    const phoneField = document.getElementById('phone');
    if (!isValidPhone(phoneField.value)) {
        showFieldError(phoneField, '올바른 전화번호를 입력해주세요.');
        isValid = false;
    }
    
    return isValid;
}

// 개별 필드 유효성 검사
function validateField(event) {
    const field = event.target;
    const value = field.value.trim();
    
    // 필수 필드 체크
    if (field.hasAttribute('required') && !value) {
        showFieldError(field, '이 필드는 필수입니다.');
        return false;
    }
    
    // 이메일 유효성 체크
    if (field.type === 'email' && value && !isValidEmail(value)) {
        showFieldError(field, '올바른 이메일 주소를 입력해주세요.');
        return false;
    }
    
    // 전화번호 유효성 체크
    if (field.type === 'tel' && value && !isValidPhone(value)) {
        showFieldError(field, '올바른 전화번호를 입력해주세요.');
        return false;
    }
    
    // 유효한 경우 에러 메시지 제거
    clearFieldError(field);
    return true;
}

// 이메일 유효성 검사
function isValidEmail(email) {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return emailRegex.test(email);
}

// 전화번호 유효성 검사
function isValidPhone(phone) {
    const phoneRegex = /^01[0-9]-\d{4}-\d{4}$/;
    return phoneRegex.test(phone);
}

// 전화번호 포맷팅
function formatPhoneNumber(event) {
    let value = event.target.value.replace(/\D/g, '');
    
    if (value.length > 3 && value.length <= 7) {
        value = value.replace(/(\d{3})(\d+)/, '$1-$2');
    } else if (value.length > 7) {
        value = value.replace(/(\d{3})(\d{4})(\d+)/, '$1-$2-$3');
    }
    
    event.target.value = value;
}

// 필드 에러 표시
function showFieldError(field, message) {
    clearFieldError(field);
    
    field.style.borderColor = '#ff4b2b';
    field.style.backgroundColor = 'rgba(255, 75, 43, 0.05)';
    
    const errorDiv = document.createElement('div');
    errorDiv.className = 'field-error';
    errorDiv.style.color = '#ff4b2b';
    errorDiv.style.fontSize = '0.85rem';
    errorDiv.style.marginTop = '5px';
    errorDiv.textContent = message;
    
    field.parentNode.appendChild(errorDiv);
}

// 필드 에러 제거
function clearFieldError(field) {
    field.style.borderColor = '';
    field.style.backgroundColor = '';
    
    const existingError = field.parentNode.querySelector('.field-error');
    if (existingError) {
        existingError.remove();
    }
}

// 로딩 상태 설정
function setLoadingState(isLoading) {
    const submitBtn = document.getElementById('submitBtn');
    const btnText = submitBtn.querySelector('.btn-text');
    const btnLoader = submitBtn.querySelector('.btn-loader');
    const form = document.getElementById('reservationForm');
    
    if (isLoading) {
        submitBtn.disabled = true;
        btnText.style.display = 'none';
        btnLoader.style.display = 'inline-flex';
        form.classList.add('loading');
    } else {
        resetSubmitButton();
        form.classList.remove('loading');
    }
}

// 제출 버튼 리셋
function resetSubmitButton() {
    const submitBtn = document.getElementById('submitBtn');
    const btnText = submitBtn.querySelector('.btn-text');
    const btnLoader = submitBtn.querySelector('.btn-loader');
    
    submitBtn.disabled = false;
    btnText.style.display = 'inline';
    btnLoader.style.display = 'none';
}

// 메시지 표시
function showMessage(text, type = 'success') {
    const messageContainer = document.getElementById('messageContainer');
    const messageContent = document.getElementById('messageContent');
    
    messageContent.textContent = text;
    messageContent.className = `message ${type}`;
    messageContainer.style.display = 'block';
    
    // 5초 후 자동으로 닫기
    setTimeout(() => {
        hideMessage();
    }, 5000);
}

// 메시지 숨기기
function hideMessage() {
    const messageContainer = document.getElementById('messageContainer');
    messageContainer.style.display = 'none';
}

// 유틸리티: 날짜 포맷팅
function formatDate(dateString) {
    const date = new Date(dateString);
    return date.toLocaleDateString('ko-KR', {
        year: 'numeric',
        month: 'long',
        day: 'numeric',
        weekday: 'long'
    });
}

// 유틸리티: 시간 포맷팅
function formatTime(timeString) {
    const [hours, minutes] = timeString.split(':');
    const hour = parseInt(hours);
    const ampm = hour >= 12 ? '오후' : '오전';
    const displayHour = hour > 12 ? hour - 12 : hour === 0 ? 12 : hour;
    return `${ampm} ${displayHour}:${minutes}`;
}

// 상품 선택 및 즉시 예약 함수
async function selectProduct(productId, productName) {
    try {
        // 선택된 상품 정보 조회
        const productResult = await getProductById(productId);
        if (!productResult.success) {
            showMessage('상품 정보를 불러오는 중 오류가 발생했습니다.', 'error');
            return;
        }
        
        const product = productResult.data;
        
        // 상품이 이미 예약되었는지 확인
        if (product.is_booked) {
            showMessage('이미 예약된 상품입니다. 다른 상품을 선택해 주세요.', 'error');
            // 상품 목록 새로고침
            if (customCalendar && customCalendar.selectedDate) {
                customCalendar.loadAvailableProducts(customCalendar.selectedDate);
            }
            return;
        }
        
        // 예약 확인 다이얼로그 표시
        const confirmed = await showBookingConfirmDialog(product);
        if (!confirmed) {
            return;
        }
        
        // 고객 정보 입력 다이얼로그 표시
        const customerInfo = await showCustomerInfoDialog();
        if (!customerInfo) {
            return;
        }
        
        // 로딩 상태 표시
        showMessage('예약을 처리하고 있습니다...', 'info');
        
        // 1. 상품을 예약됨 상태로 변경
        const bookResult = await bookProduct(productId);
        if (!bookResult.success) {
            showMessage('상품 예약 처리 중 오류가 발생했습니다.', 'error');
            return;
        }
        
        // 2. 예약현황(bookings) 테이블에 데이터 추가
        const bookingData = {
            customer_name: customerInfo.name,
            customer_phone: customerInfo.phone,
            customer_email: customerInfo.email || null,
            booking_date: product.product_date,
            booking_time: product.start_time,
            product_name: product.product_name,
            guest_count: customerInfo.guestCount || 1,
            total_amount: product.price,
            status: 'confirmed',
            special_requests: customerInfo.message || null
        };
        
        const createBookingResult = await createBooking(bookingData);
        if (!createBookingResult.success) {
            // 예약 실패 시 상품 예약 상태 롤백
            await cancelProductBooking(productId);
            showMessage('예약 생성 중 오류가 발생했습니다.', 'error');
            return;
        }
        
        // 성공 메시지 표시
        showMessage(`${productName} 예약이 완료되었습니다!`, 'success');
        
        // 예약 가능한 상품 목록 숨기기
        const container = document.getElementById('availableProductsContainer');
        if (container) {
            container.style.display = 'none';
        }
        
        // 예약 완료 정보 표시
        showBookingCompletionInfo(product, customerInfo);
        
        console.log(`예약 완료: ${productName} (ID: ${productId})`);
        
    } catch (error) {
        console.error('상품 예약 오류:', error);
        showMessage('예약 처리 중 오류가 발생했습니다.', 'error');
    }
}

// 예약 확인 다이얼로그
function showBookingConfirmDialog(product) {
    return new Promise((resolve) => {
        const confirmed = confirm(
            `다음 상품을 예약하시겠습니까?\n\n` +
            `상품명: ${product.product_name}\n` +
            `날짜: ${product.product_date}\n` +
            `시간: ${formatTimeRange(product.start_time, product.end_time)}\n` +
            `가격: ₩${product.price.toLocaleString()}\n` +
            `설명: ${product.description || '없음'}`
        );
        resolve(confirmed);
    });
}

// 고객 정보 입력 다이얼로그
function showCustomerInfoDialog() {
    return new Promise((resolve) => {
        const name = prompt('성함을 입력하세요:');
        if (!name || name.trim() === '') {
            resolve(null);
            return;
        }
        
        const phone = prompt('연락처를 입력하세요 (예: 010-1234-5678):');
        if (!phone || phone.trim() === '') {
            resolve(null);
            return;
        }
        
        const email = prompt('이메일을 입력하세요 (선택사항):') || '';
        const message = prompt('특별 요청사항이 있으시면 입력하세요 (선택사항):') || '';
        
        resolve({
            name: name.trim(),
            phone: phone.trim(),
            email: email.trim(),
            message: message.trim()
        });
    });
}

// 예약 완료 정보 표시
function showBookingCompletionInfo(product, customerInfo) {
    const statusContainer = document.getElementById('reservationStatus');
    if (statusContainer) {
        statusContainer.innerHTML = `
            <div class="booking-completion">
                <div class="completion-header">
                    <h4>✅ 예약이 완료되었습니다!</h4>
                </div>
                <div class="completion-details">
                    <div class="detail-item">
                        <span class="detail-label">예약자:</span>
                        <span class="detail-value">${customerInfo.name}</span>
                    </div>
                    <div class="detail-item">
                        <span class="detail-label">연락처:</span>
                        <span class="detail-value">${customerInfo.phone}</span>
                    </div>
                    <div class="detail-item">
                        <span class="detail-label">상품명:</span>
                        <span class="detail-value">${product.product_name}</span>
                    </div>
                    <div class="detail-item">
                        <span class="detail-label">예약날짜:</span>
                        <span class="detail-value">${product.product_date}</span>
                    </div>
                    <div class="detail-item">
                        <span class="detail-label">예약시간:</span>
                        <span class="detail-value">${formatTimeRange(product.start_time, product.end_time)}</span>
                    </div>
                    <div class="detail-item">
                        <span class="detail-label">결제금액:</span>
                        <span class="detail-value price">₩${product.price.toLocaleString()}</span>
                    </div>
                </div>
                <div class="completion-note">
                    <p>예약 확인 메시지를 연락처로 발송해드릴 예정입니다.</p>
                    <p>문의사항이 있으시면 언제든지 연락주세요.</p>
                </div>
            </div>
        `;
        
        // 부드럽게 예약 현황으로 스크롤
        statusContainer.scrollIntoView({ behavior: 'smooth', block: 'center' });
    }
}

// 시간 범위 포맷팅 유틸리티 (calendar.js에서 사용하는 것과 동일)
function formatTimeRange(startTime, endTime) {
    const formatTime = (timeString) => {
        const [hours, minutes] = timeString.split(':');
        const hour = parseInt(hours);
        const ampm = hour >= 12 ? '오후' : '오전';
        const displayHour = hour > 12 ? hour - 12 : hour === 0 ? 12 : hour;
        return `${ampm} ${displayHour}:${minutes}`;
    };
    
    return `${formatTime(startTime)} - ${formatTime(endTime)}`;
}