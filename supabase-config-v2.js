// Supabase 설정 및 API 함수 (OSO Camping BBQ 통합 시스템용)
// 새로운 카탈로그 기반 구조에 맞게 업데이트

const SUPABASE_URL = (window.__ENV && window.__ENV.SUPABASE_URL) || "";
const SUPABASE_ANON_KEY = (window.__ENV && window.__ENV.SUPABASE_ANON_KEY) || "";

if (!SUPABASE_URL || !SUPABASE_ANON_KEY) {
  console.error("Supabase 환경변수가 설정되지 않았습니다. env.js를 생성하고 값을 채워주세요.");
}

const { createClient } = supabase;
const supabaseClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

// ===============================
// 카탈로그 관련 함수들
// ===============================

// 자원 카탈로그 조회
async function getResourceCatalog() {
  try {
    const { data, error } = await supabaseClient
      .from('resource_catalog')
      .select('*')
      .eq('active', true)
      .order('category_code', { ascending: true })
      .order('internal_code', { ascending: true });
    if (error) throw error;
    return { success: true, data };
  } catch (error) {
    console.error('자원 카탈로그 조회 오류:', error);
    return { success: false, error: error.message };
  }
}

// 타임슬롯 카탈로그 조회
async function getTimeSlotCatalog() {
  try {
    const { data, error } = await supabaseClient
      .from('time_slot_catalog')
      .select('*')
      .order('start_local', { ascending: true });
    if (error) throw error;
    return { success: true, data };
  } catch (error) {
    console.error('타임슬롯 카탈로그 조회 오류:', error);
    return { success: false, error: error.message };
  }
}

// SKU 카탈로그 조회 (장소+시간 조합)
async function getSkuCatalog() {
  try {
    const { data, error } = await supabaseClient
      .from('sku_catalog')
      .select(`
        *,
        resource_catalog(*),
        time_slot_catalog(*)
      `)
      .eq('active', true)
      .eq('resource_catalog.active', true);
    if (error) throw error;
    return { success: true, data };
  } catch (error) {
    console.error('SKU 카탈로그 조회 오류:', error);
    return { success: false, error: error.message };
  }
}

// 예약 가능한 슬롯 조회 (뷰 활용)
async function getAvailableSlots() {
  try {
    const { data, error } = await supabaseClient
      .from('available_slots')
      .select('*')
      .eq('active', true);
    if (error) throw error;
    return { success: true, data };
  } catch (error) {
    console.error('예약 가능한 슬롯 조회 오류:', error);
    return { success: false, error: error.message };
  }
}

// 특정 날짜의 가용성 조회
async function getAvailabilityByDate(date) {
  try {
    const { data, error } = await supabaseClient
      .from('availability')
      .select(`
        *,
        sku_catalog(
          sku_code,
          resource_catalog(*),
          time_slot_catalog(*)
        )
      `)
      .eq('date', date)
      .eq('blocked', false);
    if (error) throw error;
    return { success: true, data };
  } catch (error) {
    console.error('날짜별 가용성 조회 오류:', error);
    return { success: false, error: error.message };
  }
}

// 가용성 초기화 (특정 날짜의 모든 SKU에 대해 기본 가용성 생성)
async function initializeAvailability(date) {
  try {
    // 해당 날짜에 가용성 데이터가 있는지 확인
    const { data: existing } = await supabaseClient
      .from('availability')
      .select('sku_code')
      .eq('date', date);

    if (existing && existing.length > 0) {
      return { success: true, message: '이미 가용성 데이터가 존재합니다.' };
    }

    // 모든 활성 SKU 조회
    const skuResult = await getSkuCatalog();
    if (!skuResult.success) throw new Error(skuResult.error);

    // 각 SKU에 대해 가용성 레코드 생성
    const availabilityData = skuResult.data.map(sku => ({
      sku_code: sku.sku_code,
      date: date,
      available_slots: 1,
      booked_slots: 0,
      blocked: false
    }));

    const { error } = await supabaseClient
      .from('availability')
      .insert(availabilityData);

    if (error) throw error;
    return { success: true, message: `${availabilityData.length}개의 가용성 레코드가 생성되었습니다.` };
  } catch (error) {
    console.error('가용성 초기화 오류:', error);
    return { success: false, error: error.message };
  }
}

// ===============================
// 예약 신청 관련 함수들
// ===============================

async function createReservation(reservationData) {
  try {
    const { data, error } = await supabaseClient
      .from('reservations')
      .insert([reservationData])
      .select();
    if (error) throw error;
    return { success: true, data };
  } catch (error) {
    console.error('예약 신청 생성 오류:', error);
    return { success: false, error: error.message };
  }
}

async function getReservations() {
  try {
    const { data, error } = await supabaseClient
      .from('reservation_details')  // 뷰 사용
      .select('*')
      .order('created_at', { ascending: false });
    if (error) throw error;
    return { success: true, data };
  } catch (error) {
    console.error('예약 조회 오류:', error);
    return { success: false, error: error.message };
  }
}

async function getReservationById(id) {
  try {
    const { data, error } = await supabaseClient
      .from('reservation_details')  // 뷰 사용
      .select('*')
      .eq('id', id)
      .single();
    if (error) throw error;
    return { success: true, data };
  } catch (error) {
    console.error('예약 단건 조회 오류:', error);
    return { success: false, error: error.message };
  }
}

async function updateReservation(id, updates) {
  try {
    const { data, error } = await supabaseClient
      .from('reservations')
      .update(updates)
      .eq('id', id)
      .select();
    if (error) throw error;
    return { success: true, data };
  } catch (error) {
    console.error('예약 업데이트 오류:', error);
    return { success: false, error: error.message };
  }
}

async function deleteReservation(id) {
  try {
    const { error } = await supabaseClient
      .from('reservations')
      .delete()
      .eq('id', id);
    if (error) throw error;
    return { success: true };
  } catch (error) {
    console.error('예약 삭제 오류:', error);
    return { success: false, error: error.message };
  }
}

// 예약 신청을 예약 현황으로 확정
async function confirmReservation(reservationId, bookingData) {
  try {
    // 트랜잭션 시작
    const { data: reservation, error: reservationError } = await supabaseClient
      .from('reservations')
      .select('*')
      .eq('id', reservationId)
      .single();
    
    if (reservationError) throw reservationError;

    // 예약 현황 테이블에 추가
    const { data: booking, error: bookingError } = await supabaseClient
      .from('bookings')
      .insert([{
        customer_name: reservation.name,
        customer_phone: reservation.phone,
        customer_email: reservation.email,
        booking_date: reservation.reservation_date,
        sku_code: reservation.sku_code,
        guest_count: reservation.guest_count || 1,
        base_price: bookingData.base_price,
        total_amount: bookingData.total_amount,
        special_requests: reservation.special_requests,
        ...bookingData
      }])
      .select();

    if (bookingError) throw bookingError;

    // 예약 신청 상태를 확정으로 변경
    await updateReservation(reservationId, { status: 'confirmed' });

    // 가용성 업데이트 (예약된 슬롯 수 증가)
    const { error: availabilityError } = await supabaseClient
      .from('availability')
      .update({ 
        booked_slots: supabaseClient.sql`booked_slots + 1` 
      })
      .eq('sku_code', reservation.sku_code)
      .eq('date', reservation.reservation_date);

    if (availabilityError) throw availabilityError;

    return { success: true, data: booking };
  } catch (error) {
    console.error('예약 확정 오류:', error);
    return { success: false, error: error.message };
  }
}

// ===============================
// 예약 현황 관련 함수들
// ===============================

async function getBookings() {
  try {
    const { data, error } = await supabaseClient
      .from('booking_details')  // 뷰 사용
      .select('*')
      .order('created_at', { ascending: false });
    if (error) throw error;
    return { success: true, data };
  } catch (error) {
    console.error('예약 현황 조회 오류:', error);
    return { success: false, error: error.message };
  }
}

async function getBookingById(id) {
  try {
    const { data, error } = await supabaseClient
      .from('booking_details')  // 뷰 사용
      .select('*')
      .eq('id', id)
      .single();
    if (error) throw error;
    return { success: true, data };
  } catch (error) {
    console.error('예약 현황 단건 조회 오류:', error);
    return { success: false, error: error.message };
  }
}

async function createBooking(bookingData) {
  try {
    const { data, error } = await supabaseClient
      .from('bookings')
      .insert([bookingData])
      .select();
    if (error) throw error;
    return { success: true, data };
  } catch (error) {
    console.error('예약 현황 등록 오류:', error);
    return { success: false, error: error.message };
  }
}

async function updateBooking(id, updates) {
  try {
    const { data, error } = await supabaseClient
      .from('bookings')
      .update(updates)
      .eq('id', id)
      .select();
    if (error) throw error;
    return { success: true, data };
  } catch (error) {
    console.error('예약 현황 업데이트 오류:', error);
    return { success: false, error: error.message };
  }
}

async function deleteBooking(id) {
  try {
    const { error } = await supabaseClient
      .from('bookings')
      .delete()
      .eq('id', id);
    if (error) throw error;
    return { success: true };
  } catch (error) {
    console.error('예약 현황 삭제 오류:', error);
    return { success: false, error: error.message };
  }
}

// ===============================
// 유틸리티 함수들
// ===============================

// 요금 계산 (기본요금 × 시간대 할증 × 인원수 등)
function calculateTotalPrice(basePrice, priceMultiplier = 1.0, guestCount = 1, additionalFees = 0) {
  const adjustedPrice = Math.round(basePrice * priceMultiplier);
  return adjustedPrice + additionalFees;
}

// 카테고리명 한글 변환
function getCategoryDisplayName(categoryCode) {
  const categoryMap = {
    'PR': '프라이빗룸',
    'ST': '소파테이블', 
    'TN': '텐트동',
    'VP': 'VIP동',
    'YT': '야장테이블'
  };
  return categoryMap[categoryCode] || categoryCode;
}

// 시간 포맷팅
function formatTimeSlot(startTime, endTime) {
  return `${startTime.substring(0,5)} - ${endTime.substring(0,5)}`;
}

// ===============================
// 전역 노출 (브라우저 환경)
// ===============================

// 카탈로그 함수
window.getResourceCatalog = getResourceCatalog;
window.getTimeSlotCatalog = getTimeSlotCatalog;
window.getSkuCatalog = getSkuCatalog;
window.getAvailableSlots = getAvailableSlots;
window.getAvailabilityByDate = getAvailabilityByDate;
window.initializeAvailability = initializeAvailability;

// 예약 신청 함수
window.createReservation = createReservation;
window.getReservations = getReservations;
window.getReservationById = getReservationById;
window.updateReservation = updateReservation;
window.deleteReservation = deleteReservation;
window.confirmReservation = confirmReservation;

// 예약 현황 함수
window.getBookings = getBookings;
window.getBookingById = getBookingById;
window.createBooking = createBooking;
window.updateBooking = updateBooking;
window.deleteBooking = deleteBooking;

// 유틸리티 함수
window.calculateTotalPrice = calculateTotalPrice;
window.getCategoryDisplayName = getCategoryDisplayName;
window.formatTimeSlot = formatTimeSlot;