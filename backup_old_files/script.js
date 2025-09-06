// 페이지 로드 시 초기화 (orig: 주석과 코드가 한 줄에 붙어 있었습니다)
document.addEventListener('DOMContentLoaded', function () {
  initializeForm();
  setupEventListeners();
  setMinDate();
});

function initializeForm() {
  const form = document.getElementById('reservationForm');
  if (form) form.reset();
  resetSubmitButton();
}

function resetSubmitButton() {
  const btn = document.getElementById('submitBtn');
  if (!btn) return;
  const text = btn.querySelector('.btn-text');
  const loader = btn.querySelector('.btn-loader');
  btn.disabled = false;
  if (text) text.style.display = 'inline';
  if (loader) loader.style.display = 'none';
}

function setupEventListeners() {
  const form = document.getElementById('reservationForm');
  const closeMessageBtn = document.getElementById('closeMessage');

  if (form) form.addEventListener('submit', handleFormSubmit);
  if (closeMessageBtn) closeMessageBtn.addEventListener('click', hideMessage);

  const phoneInput = document.getElementById('phone');
  if (phoneInput) phoneInput.addEventListener('input', formatPhoneNumber);

  if (form) {
    const requiredFields = form.querySelectorAll('input[required], select[required]');
    requiredFields.forEach((field) => field.addEventListener('blur', validateField));
  }
}

// 최소 날짜 설정 (오늘부터 선택 가능)
function setMinDate() {
  const dateInput = document.getElementById('reservation_date');
  if (!dateInput) return;
  const today = new Date().toISOString().split('T')[0];
  dateInput.min = today;
}

// 폼 제출 처리
async function handleFormSubmit(event) {
  event.preventDefault();

  const form = event.target;
  const formData = new FormData(form);

  if (!validateForm(form)) return;

  setLoadingState(true);
  try {
    const reservationData = {
      name: (formData.get('name') || '').trim(),
      phone: (formData.get('phone') || '').trim(),
      email: (formData.get('email') || '').trim() || null,
      reservation_date: formData.get('reservation_date'),
      reservation_time: formData.get('reservation_time'),
      service_type: formData.get('service_type') || null,
      message: (formData.get('message') || '').trim() || null,
      status: 'pending',
    };

    // 시간 중복 체크 (orig 메시지 보존)
    const isDuplicate = await checkTimeConflict(
      reservationData.reservation_date,
      reservationData.reservation_time
    );
    if (isDuplicate) {
      // orig: '해당 시간은 이미 예약되었습니다. 다른 시간을 선택해주세요.'
      showMessage('해당 시간은 이미 예약되었습니다. 다른 시간을 선택해주세요.', 'error');
      setLoadingState(false);
      return;
    }

    // Supabase에 예약 생성
    const result = await createReservation(reservationData);
    if (result.success) {
      // orig: '예약이 성공적으로 접수되었습니다.'
      showMessage('예약이 성공적으로 접수되었습니다.', 'success');
      form.reset();
      setMinDate();
    } else {
      throw new Error(result.error || '예약 요청 처리 중 오류가 발생했습니다.');
    }
  } catch (err) {
    console.error('예약 요청 오류:', err);
    showMessage(err.message || '예약 요청 처리 중 오류가 발생했습니다.', 'error');
  } finally {
    setLoadingState(false);
  }
}

// 시간 중복 체크
async function checkTimeConflict(date, time) {
  try {
    const result = await getReservationsByDate(date);
    if (result.success && result.data) {
      return result.data.some((r) => r.reservation_time === time);
    }
    return false;
  } catch (err) {
    console.error('시간 중복 체크 오류:', err);
    return false;
  }
}

// 폼 유효성 검사
function validateForm(form) {
  let isValid = true;
  const requiredFields = form.querySelectorAll('input[required], select[required]');
  requiredFields.forEach((field) => {
    if (!validateField({ target: field })) isValid = false;
  });

  const emailField = document.getElementById('email');
  if (emailField.value && !isValidEmail(emailField.value)) {
    // orig: '올바른 이메일 주소를 입력해주세요.'
    showFieldError(emailField, '올바른 이메일 주소를 입력해주세요.');
    isValid = false;
  }

  const phoneField = document.getElementById('phone');
  if (!isValidPhone(phoneField.value)) {
    // orig: '올바른 전화번호를 입력해주세요.'
    showFieldError(phoneField, '올바른 전화번호를 입력해주세요.');
    isValid = false;
  }

  return isValid;
}

function validateField(e) {
  const field = e.target;
  const value = (field.value || '').trim();
  if (!value) {
    showFieldError(field, '필수 입력 항목입니다.'); // orig: '필수'
    return false;
  }
  clearFieldError(field);
  return true;
}

function isValidEmail(email) {
  const re = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return re.test(String(email).toLowerCase());
}

function isValidPhone(phone) {
  const re = /^(01[016789])-(\d{3,4})-(\d{4})$/;
  return re.test(phone);
}

function showFieldError(field, message) {
  field.classList.add('error');
  field.setAttribute('aria-invalid', 'true');
  field.title = message;
}

function clearFieldError(field) {
  field.classList.remove('error');
  field.removeAttribute('aria-invalid');
  field.removeAttribute('title');
}

function formatPhoneNumber(e) {
  let v = e.target.value.replace(/[^0-9]/g, '');
  if (v.length < 4) {
    e.target.value = v;
  } else if (v.length < 8) {
    e.target.value = `${v.slice(0,3)}-${v.slice(3)}`;
  } else {
    e.target.value = `${v.slice(0,3)}-${v.slice(3,7)}-${v.slice(7,11)}`;
  }
}

function showMessage(text, type = 'success') {
  const container = document.getElementById('messageContainer');
  const content = document.getElementById('messageContent');
  if (!container || !content) return;
  content.textContent = text;
  content.className = `message ${type}`;
  container.style.display = 'block';
  setTimeout(hideMessage, 5000);
}

function hideMessage() {
  const container = document.getElementById('messageContainer');
  if (container) container.style.display = 'none';
}

function setLoadingState(loading) {
  const btn = document.getElementById('submitBtn');
  if (!btn) return;
  const text = btn.querySelector('.btn-text');
  const loader = btn.querySelector('.btn-loader');
  btn.disabled = loading;
  if (text) text.style.display = loading ? 'none' : 'inline';
  if (loader) loader.style.display = loading ? 'inline-flex' : 'none';
}

// 제품 선택 → 즉시 예약 처리 흐름 (캘린더 연계)
async function selectProduct(productId, productName) {
  try {
    const productResult = await getProductById(productId);
    if (!productResult.success) {
      showMessage('제품 정보를 불러오는 중 오류가 발생했습니다.', 'error');
      return;
    }
    const product = productResult.data;

    if (product.is_booked) {
      // orig: 이미 예약된 상품
      showMessage('이미 예약된 상품입니다. 다른 상품을 선택하세요.', 'error');
      if (window.customCalendar && customCalendar.selectedDate) {
        customCalendar.loadAvailableProducts(customCalendar.selectedDate);
      }
      return;
    }

    const confirmed = await showBookingConfirmDialog(product);
    if (!confirmed) return;

    const customerInfo = await showCustomerInfoDialog();
    if (!customerInfo) return;

    showMessage('예약을 처리하고 있습니다...', 'info');

    const bookResult = await bookProduct(productId);
    if (!bookResult.success) {
      showMessage('상품 예약 처리 중 오류가 발생했습니다.', 'error');
      return;
    }

    const bookingData = {
      customer_name: customerInfo.name,
      customer_phone: customerInfo.phone,
      customer_email: customerInfo.email || null,
      booking_date: product.product_date,
      booking_time: product.start_time,
      product_name: product.display_name || product.product_name,
      product_code: product.product_code,
      guest_count: customerInfo.guestCount || 1,
      total_amount: product.price,
      status: 'confirmed',
      special_requests: customerInfo.message || null,
    };

    const createBookingResult = await createBooking(bookingData);
    if (!createBookingResult.success) {
      await cancelProductBooking(productId);
      showMessage('예약 생성 중 오류가 발생했습니다.', 'error');
      return;
    }

    showMessage(`${productName} 예약이 완료되었습니다.`, 'success');

    const container = document.getElementById('availableProductsContainer');
    if (container) container.style.display = 'none';

    console.log(`예약 완료: ${productName} (ID: ${productId})`);
  } catch (err) {
    console.error('상품 예약 오류:', err);
    showMessage('예약 처리 중 오류가 발생했습니다.', 'error');
  }
}

function showBookingConfirmDialog(product) {
  return new Promise((resolve) => {
    const confirmed = confirm(
      // orig: 일부 문자열과 통화기호가 손상되어 복구
      `다음 상품을 예약하시겠습니까?\n\n` +
      `상품: ${product.display_name || product.product_name}\n` +
      `날짜: ${product.product_date}\n` +
      `시간: ${formatTimeRange(product.start_time, product.end_time)}\n` +
      `가격: ₩${Number(product.price || 0).toLocaleString()}\n` +
      `설명: ${product.description || '없음'}`
    );
    resolve(confirmed);
  });
}

function showCustomerInfoDialog() {
  return new Promise((resolve) => {
    const name = prompt('이름을 입력하세요:');
    if (!name || name.trim() === '') return resolve(null);

    const phone = prompt('연락처를 입력하세요 (예: 010-1234-5678):');
    if (!phone || phone.trim() === '') return resolve(null);

    const email = prompt('이메일을 입력하세요(선택):') || '';
    const message = prompt('특별 요청이 있으면 입력하세요(선택):') || '';

    resolve({ name: name.trim(), phone: phone.trim(), email: email.trim(), message: message.trim() });
  });
}

function formatTimeRange(startTime, endTime) {
  return `${formatTime(startTime)} - ${formatTime(endTime)}`;
}

function formatTime(timeString) {
  if (!timeString) return '';
  const [hours, minutes] = String(timeString).split(':');
  const hour = parseInt(hours, 10);
  const ampm = hour >= 12 ? '오후' : '오전';
  const displayHour = hour > 12 ? hour - 12 : hour === 0 ? 12 : hour;
  return `${ampm} ${displayHour}:${minutes}`;
}

// 상품 업데이트 함수
async function updateProduct(productId, updateData) {
  try {
    if (!supabaseClient) throw new Error('Supabase 클라이언트가 초기화되지 않았습니다.');

    const { data, error } = await supabaseClient
      .from('products')
      .update({
        ...updateData,
        updated_at: new Date().toISOString()
      })
      .eq('id', productId)
      .select();

    if (error) throw error;
    return { success: true, data: data?.[0] };
  } catch (error) {
    console.error('상품 업데이트 오류:', error);
    return { success: false, error: error.message };
  }
}

// 상품 삭제 함수
async function deleteProduct(productId) {
  try {
    if (!supabaseClient) throw new Error('Supabase 클라이언트가 초기화되지 않았습니다.');

    // 실제 삭제 대신 status를 'deleted'로 변경
    const { data, error } = await supabaseClient
      .from('products')
      .update({ 
        status: 'deleted',
        updated_at: new Date().toISOString()
      })
      .eq('id', productId)
      .select();

    if (error) throw error;
    return { success: true, data: data?.[0] };
  } catch (error) {
    console.error('상품 삭제 오류:', error);
    return { success: false, error: error.message };
  }
}

// 전역에서 접근 가능하도록 내보내기 (캘린더에서 호출)
window.selectProduct = selectProduct;
window.updateProduct = updateProduct;
window.deleteProduct = deleteProduct;

