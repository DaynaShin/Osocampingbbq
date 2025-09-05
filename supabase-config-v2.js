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
// Phase 2.4: 고객 계정 및 예약 조회 함수들
// ===============================

// 간단 예약 조회 (예약번호 + 전화번호)
async function lookupReservationSimple(reservationNumber, phone) {
  try {
    const { data, error } = await supabaseClient.rpc('lookup_reservation_simple', {
      p_reservation_number: reservationNumber,
      p_phone: phone
    });
    
    if (error) throw error;
    return { success: true, data };
  } catch (error) {
    console.error('간단 예약 조회 오류:', error);
    return { success: false, error: error.message };
  }
}

// 고객 계정 생성
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

// 고객 로그인
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

// 고객의 모든 예약 조회
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

// ===============================
// 유틸리티 함수들
// ===============================

// 주말 여부 확인 함수 (토요일, 일요일)
function isWeekend(date) {
  const day = new Date(date).getDay();
  return day === 0 || day === 6; // 일요일(0), 토요일(6)
}

// 요일별 multiplier 계산
function getTimeSlotMultiplier(timeSlotData, reservationDate, hasWeekendPricing = false) {
  if (!hasWeekendPricing) {
    // 주말 가격 정책이 없는 경우 기본 multiplier 사용
    return timeSlotData.price_multiplier || 1.0;
  }
  
  // VIP동 등 주말 가격 정책이 있는 경우
  if (isWeekend(reservationDate)) {
    return timeSlotData.weekend_multiplier || timeSlotData.price_multiplier || 1.2;
  } else {
    return timeSlotData.weekday_multiplier || timeSlotData.price_multiplier || 1.0;
  }
}

// Supabase 함수 호출 (추가 인원 요금 계산)
async function calculateTotalPriceWithGuests(resourceCode, timeSlotCode, reservationDate, guestCount = 1) {
  try {
    const { data, error } = await supabaseClient.rpc('calculate_total_price_with_guests', {
      p_resource_code: resourceCode,
      p_time_slot_code: timeSlotCode,
      p_reservation_date: reservationDate,
      p_guest_count: guestCount
    });
    
    if (error) throw error;
    return { success: true, data };
  } catch (error) {
    console.error('추가 인원 요금 계산 오류:', error);
    return { success: false, error: error.message };
  }
}

// 요금 계산 (기본요금 × 시간대 할증 × 요일 할증)
function calculateTotalPrice(basePrice, priceMultiplier = 1.0, guestCount = 1, additionalFees = 0) {
  const adjustedPrice = Math.round(basePrice * priceMultiplier);
  return adjustedPrice + additionalFees;
}

// 동적 가격 계산 (추가 인원 요금 포함)
function calculateDynamicPrice(resourceData, timeSlotData, reservationDate, guestCount = 1) {
  const basePrice = resourceData.price || 0;
  const baseGuests = resourceData.base_guests || 4;
  const extraGuestFee = resourceData.extra_guest_fee || 0;
  const maxExtraGuests = resourceData.max_extra_guests || 0;
  const maxGuests = baseGuests + maxExtraGuests;
  const hasWeekendPricing = resourceData.has_weekend_pricing || false;
  
  // 인원수 유효성 검증
  if (guestCount > maxGuests) {
    throw new Error(`최대 수용 인원을 초과했습니다. (최대: ${maxGuests}명)`);
  }
  
  // 시간대별 multiplier (평일/주말 구분)
  const timeMultiplier = getTimeSlotMultiplier(timeSlotData, reservationDate, hasWeekendPricing);
  
  // 기본 가격 계산 (기본 인원까지)
  const baseTotal = Math.round(basePrice * timeMultiplier);
  
  // 추가 인원 계산
  const extraGuests = Math.max(0, guestCount - baseGuests);
  const extraGuestsFee = extraGuests * extraGuestFee;
  
  // 최종 가격
  const finalPrice = baseTotal + extraGuestsFee;
  
  return {
    basePrice,
    timeMultiplier,
    baseTotal,
    baseGuests,
    guestCount,
    extraGuests,
    extraGuestFeePerPerson: extraGuestFee,
    extraGuestsFeeTotal: extraGuestsFee,
    finalPrice,
    maxGuests,
    isWeekendRate: hasWeekendPricing && isWeekend(reservationDate),
    priceBreakdown: {
      baseFacility: baseTotal,
      extraGuests: extraGuestsFee,
      total: finalPrice
    }
  };
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

// ===============================
// 관리자용 고객 계정 연동 함수들
// ===============================

// 관리자용 예약 조회 (계정 정보 포함)
async function getAdminReservationsWithCustomer() {
  try {
    const { data, error } = await supabaseClient.rpc('get_admin_reservations_with_customer');
    
    if (error) throw error;
    return { success: true, data };
  } catch (error) {
    console.error('관리자용 예약 조회 오류:', error);
    return { success: false, error: error.message };
  }
}

// 고객 프로필 요약 조회
async function getCustomerProfilesSummary() {
  try {
    const { data, error } = await supabaseClient.rpc('get_customer_profiles_summary');
    
    if (error) throw error;
    return { success: true, data };
  } catch (error) {
    console.error('고객 프로필 요약 조회 오류:', error);
    return { success: false, error: error.message };
  }
}

// 고객 계정 통계 조회
async function getCustomerAccountStats() {
  try {
    const { data, error } = await supabaseClient.rpc('get_customer_account_stats');
    
    if (error) throw error;
    return { success: true, data: data[0] };
  } catch (error) {
    console.error('고객 계정 통계 조회 오류:', error);
    return { success: false, error: error.message };
  }
}

// 관리자용 고객 계정 연동 함수들 노출
window.getAdminReservationsWithCustomer = getAdminReservationsWithCustomer;
window.getCustomerProfilesSummary = getCustomerProfilesSummary;
window.getCustomerAccountStats = getCustomerAccountStats;

// ===============================
// Phase 3.1: 실시간 알림 시스템
// ===============================

// 실시간 알림 시스템 클래스
class RealtimeNotificationSystem {
  constructor() {
    this.isInitialized = false;
    this.channels = new Map();
    this.onNotificationHandlers = new Set();
    this.unreadCount = 0;
    this.notifications = [];
  }

  // 초기화
  async initialize(recipientType = 'admin', recipientId = 'admin') {
    if (this.isInitialized) return;

    this.recipientType = recipientType;
    this.recipientId = recipientId;

    try {
      // 기존 알림 불러오기
      await this.loadExistingNotifications();

      // Realtime 채널 구독
      this.subscribeToNotifications();

      // 브라우저 알림 권한 요청
      await this.requestNotificationPermission();

      this.isInitialized = true;
      console.log('실시간 알림 시스템 초기화 완료');
    } catch (error) {
      console.error('알림 시스템 초기화 오류:', error);
    }
  }

  // 기존 알림 불러오기
  async loadExistingNotifications() {
    try {
      let result;
      if (this.recipientType === 'admin') {
        result = await getAdminNotifications();
      } else {
        result = await getCustomerNotifications(this.recipientId);
      }

      if (result.success) {
        this.notifications = result.data || [];
        this.unreadCount = this.notifications.filter(n => !n.is_read).length;
        this.notifyHandlers('initialized', { notifications: this.notifications, unreadCount: this.unreadCount });
      }
    } catch (error) {
      console.error('기존 알림 로드 오류:', error);
    }
  }

  // Realtime 채널 구독
  subscribeToNotifications() {
    const channel = supabaseClient
      .channel('notifications-channel')
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'notifications',
          filter: `recipient_type=eq.${this.recipientType}${this.recipientType === 'customer' ? `AND recipient_id=eq.${this.recipientId}` : ''}`
        },
        (payload) => {
          console.log('새 알림 수신:', payload);
          this.handleNewNotification(payload.new);
        }
      )
      .subscribe();

    this.channels.set('notifications', channel);
  }

  // 새 알림 처리
  handleNewNotification(notification) {
    // 알림 목록에 추가 (맨 앞에)
    this.notifications.unshift(notification);
    
    // 읽지 않은 알림 수 증가
    if (!notification.is_read) {
      this.unreadCount++;
    }

    // 브라우저 알림 표시
    this.showBrowserNotification(notification);

    // 핸들러들에게 알림
    this.notifyHandlers('newNotification', { 
      notification, 
      notifications: this.notifications,
      unreadCount: this.unreadCount 
    });
  }

  // 브라우저 알림 권한 요청
  async requestNotificationPermission() {
    if (!('Notification' in window)) {
      console.warn('이 브라우저는 알림을 지원하지 않습니다.');
      return false;
    }

    const permission = await Notification.requestPermission();
    return permission === 'granted';
  }

  // 브라우저 알림 표시
  showBrowserNotification(notification) {
    if (!('Notification' in window) || Notification.permission !== 'granted') {
      return;
    }

    const options = {
      body: notification.message,
      icon: '/favicon.ico', // 사이트 아이콘
      badge: '/favicon.ico',
      tag: `notification-${notification.id}`,
      requireInteraction: notification.priority === 'urgent' || notification.priority === 'high',
      silent: notification.priority === 'low'
    };

    const browserNotification = new Notification(notification.title, options);
    
    // 클릭 시 해당 예약으로 이동
    browserNotification.onclick = () => {
      window.focus();
      if (notification.reservation_number) {
        // 예약 조회 페이지로 이동하거나 모달 표시
        this.notifyHandlers('notificationClicked', { notification });
      }
      browserNotification.close();
    };

    // 5초 후 자동 닫기 (urgent/high 제외)
    if (notification.priority !== 'urgent' && notification.priority !== 'high') {
      setTimeout(() => browserNotification.close(), 5000);
    }
  }

  // 알림 읽음 처리
  async markAsRead(notificationId) {
    try {
      const result = await markNotificationAsRead(notificationId);
      if (result.success) {
        // 로컬 상태 업데이트
        const notification = this.notifications.find(n => n.id === notificationId);
        if (notification && !notification.is_read) {
          notification.is_read = true;
          this.unreadCount = Math.max(0, this.unreadCount - 1);
          
          this.notifyHandlers('notificationRead', { 
            notificationId,
            unreadCount: this.unreadCount 
          });
        }
      }
      return result;
    } catch (error) {
      console.error('알림 읽음 처리 오류:', error);
      return { success: false, error: error.message };
    }
  }

  // 모든 알림 읽음 처리
  async markAllAsRead() {
    const unreadIds = this.notifications
      .filter(n => !n.is_read)
      .map(n => n.id);

    for (const id of unreadIds) {
      await this.markAsRead(id);
    }
  }

  // 이벤트 핸들러 등록
  onNotification(handler) {
    this.onNotificationHandlers.add(handler);
    return () => this.onNotificationHandlers.delete(handler);
  }

  // 핸들러들에게 이벤트 알림
  notifyHandlers(eventType, data) {
    this.onNotificationHandlers.forEach(handler => {
      try {
        handler(eventType, data);
      } catch (error) {
        console.error('알림 핸들러 오류:', error);
      }
    });
  }

  // 정리
  cleanup() {
    this.channels.forEach(channel => {
      supabaseClient.removeChannel(channel);
    });
    this.channels.clear();
    this.onNotificationHandlers.clear();
    this.isInitialized = false;
  }

  // 상태 정보 반환
  getState() {
    return {
      isInitialized: this.isInitialized,
      unreadCount: this.unreadCount,
      notifications: this.notifications,
      recipientType: this.recipientType,
      recipientId: this.recipientId
    };
  }
}

// 싱글톤 인스턴스
const notificationSystem = new RealtimeNotificationSystem();

// 고객용 알림 조회
async function getCustomerNotifications(phone, limit = 20) {
  try {
    const { data, error } = await supabaseClient.rpc('get_customer_notifications', {
      p_phone: phone,
      p_limit: limit
    });
    
    if (error) throw error;
    return { success: true, data };
  } catch (error) {
    console.error('고객 알림 조회 오류:', error);
    return { success: false, error: error.message };
  }
}

// 관리자용 알림 조회
async function getAdminNotifications(limit = 50) {
  try {
    const { data, error } = await supabaseClient.rpc('get_admin_notifications', {
      p_limit: limit
    });
    
    if (error) throw error;
    return { success: true, data };
  } catch (error) {
    console.error('관리자 알림 조회 오류:', error);
    return { success: false, error: error.message };
  }
}

// 알림 읽음 상태 업데이트
async function markNotificationAsRead(notificationId) {
  try {
    const { data, error } = await supabaseClient.rpc('mark_notification_as_read', {
      p_notification_id: notificationId
    });
    
    if (error) throw error;
    return { success: true, data };
  } catch (error) {
    console.error('알림 읽음 처리 오류:', error);
    return { success: false, error: error.message };
  }
}

// 테스트용 알림 생성
async function createTestNotification(type = 'test', recipientType = 'admin') {
  try {
    const { data, error } = await supabaseClient.rpc('create_test_notification', {
      p_type: type,
      p_recipient_type: recipientType
    });
    
    if (error) throw error;
    return { success: true, data };
  } catch (error) {
    console.error('테스트 알림 생성 오류:', error);
    return { success: false, error: error.message };
  }
}

// 실시간 알림 시스템 노출
window.notificationSystem = notificationSystem;
window.getCustomerNotifications = getCustomerNotifications;
window.getAdminNotifications = getAdminNotifications;
window.markNotificationAsRead = markNotificationAsRead;
window.createTestNotification = createTestNotification;

// 예약 현황 함수
window.getBookings = getBookings;
window.getBookingById = getBookingById;
window.createBooking = createBooking;
window.updateBooking = updateBooking;
window.deleteBooking = deleteBooking;

// 유틸리티 함수
window.calculateTotalPrice = calculateTotalPrice;
window.calculateTotalPriceWithGuests = calculateTotalPriceWithGuests;
window.calculateDynamicPrice = calculateDynamicPrice;
window.isWeekend = isWeekend;
window.getTimeSlotMultiplier = getTimeSlotMultiplier;
window.getCategoryDisplayName = getCategoryDisplayName;
window.formatTimeSlot = formatTimeSlot;

// Phase 2.4: 고객 계정 관리 함수
window.lookupReservationSimple = lookupReservationSimple;
window.createCustomerAccount = createCustomerAccount;
window.customerLogin = customerLogin;
window.getCustomerReservations = getCustomerReservations;

// =================================================================
// Phase 3.2: SMS/이메일 자동 발송 시스템
// =================================================================

class MessageService {
  constructor() {
    this.isInitialized = false;
  }

  async initialize() {
    if (this.isInitialized) return;
    
    try {
      // Supabase 연결 확인
      if (!window.supabase) {
        throw new Error('Supabase client가 초기화되지 않았습니다.');
      }
      
      this.isInitialized = true;
      console.log('MessageService initialized successfully');
    } catch (error) {
      console.error('MessageService 초기화 실패:', error);
      throw error;
    }
  }

  // 메시지 템플릿 관리
  async getMessageTemplates(templateCode = null) {
    try {
      let query = supabase
        .from('message_templates')
        .select('*')
        .eq('is_active', true);
        
      if (templateCode) {
        query = query.eq('template_code', templateCode);
      }
      
      const { data, error } = await query.order('template_name');
      
      if (error) throw error;
      return data;
    } catch (error) {
      console.error('템플릿 조회 실패:', error);
      throw error;
    }
  }

  async updateMessageTemplate(templateCode, updates) {
    try {
      const { data, error } = await supabase
        .from('message_templates')
        .update({
          ...updates,
          updated_at: new Date().toISOString()
        })
        .eq('template_code', templateCode)
        .select();
      
      if (error) throw error;
      return data[0];
    } catch (error) {
      console.error('템플릿 업데이트 실패:', error);
      throw error;
    }
  }

  // SMS 발송 관리
  async sendSMSMessage(reservationId, templateCode, phone = null) {
    try {
      const { data, error } = await supabase.rpc('send_sms_message', {
        p_reservation_id: reservationId,
        p_template_code: templateCode,
        p_phone: phone
      });
      
      if (error) throw error;
      return data; // log_id 반환
    } catch (error) {
      console.error('SMS 발송 실패:', error);
      throw error;
    }
  }

  // 이메일 발송 관리
  async sendEmailMessage(reservationId, templateCode, email = null) {
    try {
      const { data, error } = await supabase.rpc('send_email_message', {
        p_reservation_id: reservationId,
        p_template_code: templateCode,
        p_email: email
      });
      
      if (error) throw error;
      return data; // log_id 반환
    } catch (error) {
      console.error('이메일 발송 실패:', error);
      throw error;
    }
  }

  // 통합 메시지 발송 (SMS + 이메일)
  async sendReservationMessage(reservationId, templateCode, sendSMS = true, sendEmail = true) {
    try {
      const { data, error } = await supabase.rpc('send_reservation_message', {
        p_reservation_id: reservationId,
        p_template_code: templateCode,
        p_send_sms: sendSMS,
        p_send_email: sendEmail
      });
      
      if (error) throw error;
      return data; // { sms_log_id, email_log_id } 객체 반환
    } catch (error) {
      console.error('통합 메시지 발송 실패:', error);
      throw error;
    }
  }

  // 메시지 발송 로그 조회
  async getMessageLogs(limit = 50, status = null, messageType = null) {
    try {
      const { data, error } = await supabase.rpc('get_message_logs', {
        p_limit: limit,
        p_status: status,
        p_message_type: messageType
      });
      
      if (error) throw error;
      return data;
    } catch (error) {
      console.error('메시지 로그 조회 실패:', error);
      throw error;
    }
  }

  // 메시지 상태 업데이트 (외부 서비스 콜백용)
  async updateMessageStatus(logId, status, providerResponse = null, errorMessage = null) {
    try {
      const { data, error } = await supabase.rpc('update_message_status', {
        p_log_id: logId,
        p_status: status,
        p_provider_response: providerResponse,
        p_error_message: errorMessage
      });
      
      if (error) throw error;
      return data;
    } catch (error) {
      console.error('메시지 상태 업데이트 실패:', error);
      throw error;
    }
  }

  // 일일 리마인더 발송
  async sendDailyReminders() {
    try {
      const { data, error } = await supabase.rpc('send_daily_reminders');
      
      if (error) throw error;
      return data; // 발송된 리마인더 수
    } catch (error) {
      console.error('일일 리마인더 발송 실패:', error);
      throw error;
    }
  }

  // 실패한 메시지 재발송
  async retryFailedMessages(maxRetries = 3) {
    try {
      const { data, error } = await supabase.rpc('retry_failed_messages', {
        p_max_retries: maxRetries
      });
      
      if (error) throw error;
      return data; // 재발송 시도된 메시지 수
    } catch (error) {
      console.error('실패 메시지 재발송 실패:', error);
      throw error;
    }
  }

  // 메시지 시스템 테스트
  async testMessageSystem(reservationId) {
    try {
      const { data, error } = await supabase.rpc('test_message_system', {
        p_reservation_id: reservationId
      });
      
      if (error) throw error;
      return data;
    } catch (error) {
      console.error('메시지 시스템 테스트 실패:', error);
      throw error;
    }
  }

  // 템플릿 변수 치환 미리보기
  async previewMessage(templateCode, reservationId) {
    try {
      // 템플릿 가져오기
      const template = await this.getMessageTemplates(templateCode);
      if (!template || template.length === 0) {
        throw new Error('템플릿을 찾을 수 없습니다.');
      }

      // 예약 정보 가져오기
      const { data: reservation, error } = await supabase
        .from('reservations')
        .select(`
          *,
          sku_catalog (
            resource_catalog (display_name),
            time_slot_catalog (display_name)
          )
        `)
        .eq('id', reservationId)
        .single();

      if (error) throw error;

      // 변수 치환
      let content = template[0].content;
      let subject = template[0].subject || '';

      const variables = {
        '{reservation_number}': reservation.reservation_number || '',
        '{customer_name}': reservation.name || '',
        '{customer_phone}': reservation.phone || '',
        '{customer_email}': reservation.email || '',
        '{facility_name}': reservation.sku_catalog?.resource_catalog?.display_name || '',
        '{time_slot}': reservation.sku_catalog?.time_slot_catalog?.display_name || '',
        '{reservation_date}': reservation.reservation_date || '',
        '{guest_count}': reservation.guest_count?.toString() || '',
        '{total_price}': reservation.total_price?.toLocaleString() || '',
        '{checkin_time}': this.getCheckinTime(reservation.sku_catalog?.time_slot_catalog?.slot_code),
        '{cancellation_reason}': '관리자 요청'
      };

      // 변수 치환 수행
      Object.entries(variables).forEach(([key, value]) => {
        content = content.replace(new RegExp(key.replace(/[{}]/g, '\\$&'), 'g'), value);
        subject = subject.replace(new RegExp(key.replace(/[{}]/g, '\\$&'), 'g'), value);
      });

      return {
        template_code: templateCode,
        message_type: template[0].message_type,
        subject: subject,
        content: content
      };
    } catch (error) {
      console.error('메시지 미리보기 실패:', error);
      throw error;
    }
  }

  // 체크인 시간 계산 헬퍼
  getCheckinTime(timeSlotCode) {
    if (!timeSlotCode) return '체크인 시간 확인';
    
    if (timeSlotCode.includes('morning')) return '09:00';
    if (timeSlotCode.includes('afternoon')) return '14:00';
    if (timeSlotCode.includes('evening')) return '18:00';
    
    return '체크인 시간 확인';
  }

  // 발송 통계 조회
  async getMessageStats(dateFrom = null, dateTo = null) {
    try {
      let query = supabase
        .from('message_logs')
        .select('message_type, status, created_at');

      if (dateFrom) {
        query = query.gte('created_at', dateFrom);
      }
      if (dateTo) {
        query = query.lte('created_at', dateTo);
      }

      const { data, error } = await query;
      if (error) throw error;

      // 통계 계산
      const stats = {
        total: data.length,
        sms: data.filter(d => d.message_type === 'sms').length,
        email: data.filter(d => d.message_type === 'email').length,
        sent: data.filter(d => d.status === 'sent').length,
        failed: data.filter(d => d.status === 'failed').length,
        pending: data.filter(d => d.status === 'pending').length,
        delivered: data.filter(d => d.status === 'delivered').length
      };

      return stats;
    } catch (error) {
      console.error('발송 통계 조회 실패:', error);
      throw error;
    }
  }
}

// MessageService 인스턴스 생성 및 초기화
const messageService = new MessageService();

// 전역 함수로 노출
async function getMessageTemplates(templateCode = null) {
  if (!messageService.isInitialized) {
    await messageService.initialize();
  }
  return messageService.getMessageTemplates(templateCode);
}

async function updateMessageTemplate(templateCode, updates) {
  if (!messageService.isInitialized) {
    await messageService.initialize();
  }
  return messageService.updateMessageTemplate(templateCode, updates);
}

async function sendSMSMessage(reservationId, templateCode, phone = null) {
  if (!messageService.isInitialized) {
    await messageService.initialize();
  }
  return messageService.sendSMSMessage(reservationId, templateCode, phone);
}

async function sendEmailMessage(reservationId, templateCode, email = null) {
  if (!messageService.isInitialized) {
    await messageService.initialize();
  }
  return messageService.sendEmailMessage(reservationId, templateCode, email);
}

async function sendReservationMessage(reservationId, templateCode, sendSMS = true, sendEmail = true) {
  if (!messageService.isInitialized) {
    await messageService.initialize();
  }
  return messageService.sendReservationMessage(reservationId, templateCode, sendSMS, sendEmail);
}

async function getMessageLogs(limit = 50, status = null, messageType = null) {
  if (!messageService.isInitialized) {
    await messageService.initialize();
  }
  return messageService.getMessageLogs(limit, status, messageType);
}

async function updateMessageStatus(logId, status, providerResponse = null, errorMessage = null) {
  if (!messageService.isInitialized) {
    await messageService.initialize();
  }
  return messageService.updateMessageStatus(logId, status, providerResponse, errorMessage);
}

async function sendDailyReminders() {
  if (!messageService.isInitialized) {
    await messageService.initialize();
  }
  return messageService.sendDailyReminders();
}

async function retryFailedMessages(maxRetries = 3) {
  if (!messageService.isInitialized) {
    await messageService.initialize();
  }
  return messageService.retryFailedMessages(maxRetries);
}

async function testMessageSystem(reservationId) {
  if (!messageService.isInitialized) {
    await messageService.initialize();
  }
  return messageService.testMessageSystem(reservationId);
}

async function previewMessage(templateCode, reservationId) {
  if (!messageService.isInitialized) {
    await messageService.initialize();
  }
  return messageService.previewMessage(templateCode, reservationId);
}

async function getMessageStats(dateFrom = null, dateTo = null) {
  if (!messageService.isInitialized) {
    await messageService.initialize();
  }
  return messageService.getMessageStats(dateFrom, dateTo);
}

// Phase 3.2: SMS/이메일 시스템 함수 노출
window.messageService = messageService;
window.getMessageTemplates = getMessageTemplates;
window.updateMessageTemplate = updateMessageTemplate;
window.sendSMSMessage = sendSMSMessage;
window.sendEmailMessage = sendEmailMessage;
window.sendReservationMessage = sendReservationMessage;
window.getMessageLogs = getMessageLogs;
window.updateMessageStatus = updateMessageStatus;
window.sendDailyReminders = sendDailyReminders;
window.retryFailedMessages = retryFailedMessages;
window.testMessageSystem = testMessageSystem;
window.previewMessage = previewMessage;
window.getMessageStats = getMessageStats;

// =================================================================
// Phase 3.3: 예약 변경/취소 시스템
// =================================================================

class ReservationModificationService {
  constructor() {
    this.isInitialized = false;
  }

  async initialize() {
    if (this.isInitialized) return;
    
    try {
      // Supabase 연결 확인
      if (!window.supabase) {
        throw new Error('Supabase client가 초기화되지 않았습니다.');
      }
      
      this.isInitialized = true;
      console.log('ReservationModificationService initialized successfully');
    } catch (error) {
      console.error('ReservationModificationService 초기화 실패:', error);
      throw error;
    }
  }

  // 취소 정책 조회
  async getCancellationPolicies(isActive = true) {
    try {
      let query = supabase
        .from('cancellation_policies')
        .select('*');
        
      if (isActive) {
        query = query.eq('is_active', true);
      }
      
      const { data, error } = await query.order('is_default', { ascending: false });
      
      if (error) throw error;
      return data;
    } catch (error) {
      console.error('취소 정책 조회 실패:', error);
      throw error;
    }
  }

  // 적용 가능한 취소 정책 조회
  async getApplicableCancellationPolicy(reservationId) {
    try {
      const { data, error } = await supabase.rpc('get_applicable_cancellation_policy', {
        p_reservation_id: reservationId
      });
      
      if (error) throw error;
      return data;
    } catch (error) {
      console.error('적용 가능한 취소 정책 조회 실패:', error);
      throw error;
    }
  }

  // 환불 금액 계산
  async calculateRefundAmount(reservationId, cancellationDate = null) {
    try {
      const { data, error } = await supabase.rpc('calculate_refund_amount', {
        p_reservation_id: reservationId,
        p_cancellation_date: cancellationDate || new Date().toISOString()
      });
      
      if (error) throw error;
      return data;
    } catch (error) {
      console.error('환불 금액 계산 실패:', error);
      throw error;
    }
  }

  // 예약 변경 가능 여부 확인
  async canModifyReservation(reservationId, modificationType = 'change_date') {
    try {
      const { data, error } = await supabase.rpc('can_modify_reservation', {
        p_reservation_id: reservationId,
        p_modification_type: modificationType
      });
      
      if (error) throw error;
      return data;
    } catch (error) {
      console.error('예약 변경 가능 여부 확인 실패:', error);
      throw error;
    }
  }

  // 변경 가능한 옵션 조회 (날짜/시간 변경용)
  async getAvailableModificationOptions(reservationId, newDate = null) {
    try {
      const { data, error } = await supabase.rpc('get_available_modification_options', {
        p_reservation_id: reservationId,
        p_new_date: newDate
      });
      
      if (error) throw error;
      return data;
    } catch (error) {
      console.error('변경 가능한 옵션 조회 실패:', error);
      throw error;
    }
  }

  // 예약 변경 요청 생성
  async createModificationRequest(reservationId, modificationType, customerPhone, newData = null, reason = null) {
    try {
      const { data, error } = await supabase.rpc('create_modification_request', {
        p_reservation_id: reservationId,
        p_modification_type: modificationType,
        p_customer_phone: customerPhone,
        p_new_data: newData,
        p_reason: reason
      });
      
      if (error) throw error;
      return data; // modification_id 반환
    } catch (error) {
      console.error('변경 요청 생성 실패:', error);
      throw error;
    }
  }

  // 변경 요청 승인/거부 (관리자용)
  async processModificationRequest(modificationId, action, adminNotes = null, processedBy = 'admin') {
    try {
      const { data, error } = await supabase.rpc('process_modification_request', {
        p_modification_id: modificationId,
        p_action: action, // 'approve' or 'reject'
        p_admin_notes: adminNotes,
        p_processed_by: processedBy
      });
      
      if (error) throw error;
      return data;
    } catch (error) {
      console.error('변경 요청 처리 실패:', error);
      throw error;
    }
  }

  // 고객 변경 내역 조회
  async getCustomerModifications(customerPhone, limit = 10) {
    try {
      const { data, error } = await supabase.rpc('get_customer_modifications', {
        p_customer_phone: customerPhone,
        p_limit: limit
      });
      
      if (error) throw error;
      return data;
    } catch (error) {
      console.error('고객 변경 내역 조회 실패:', error);
      throw error;
    }
  }

  // 모든 변경 요청 조회 (관리자용)
  async getAllModificationRequests(status = null, limit = 50) {
    try {
      const { data, error } = await supabase.rpc('get_all_modification_requests', {
        p_status: status,
        p_limit: limit
      });
      
      if (error) throw error;
      return data;
    } catch (error) {
      console.error('모든 변경 요청 조회 실패:', error);
      throw error;
    }
  }

  // 변경 요청 상세 조회
  async getModificationRequestDetails(modificationId) {
    try {
      const { data, error } = await supabase
        .from('reservation_modifications')
        .select(`
          *,
          reservations (
            reservation_number,
            name,
            phone,
            reservation_date,
            guest_count,
            total_price,
            status,
            sku_catalog (
              resource_catalog (display_name),
              time_slot_catalog (display_name)
            )
          )
        `)
        .eq('id', modificationId)
        .single();
      
      if (error) throw error;
      return data;
    } catch (error) {
      console.error('변경 요청 상세 조회 실패:', error);
      throw error;
    }
  }

  // 예약 취소 간편 함수
  async cancelReservation(reservationId, customerPhone, reason = '고객 요청') {
    try {
      return await this.createModificationRequest(
        reservationId,
        'cancel',
        customerPhone,
        null,
        reason
      );
    } catch (error) {
      console.error('예약 취소 실패:', error);
      throw error;
    }
  }

  // 예약 날짜 변경 간편 함수
  async changeReservationDate(reservationId, customerPhone, newDate, newSkuCode = null, reason = '날짜 변경 요청') {
    try {
      const newData = {
        reservation_date: newDate
      };
      
      if (newSkuCode) {
        newData.sku_code = newSkuCode;
        
        // 새로운 SKU의 가격 계산
        const reservation = await this.getReservationById(reservationId);
        if (reservation) {
          const newPrice = await calculateTotalPriceWithGuests(newSkuCode, newDate, reservation.guest_count);
          newData.total_price = newPrice;
        }
      }
      
      return await this.createModificationRequest(
        reservationId,
        'change_date',
        customerPhone,
        newData,
        reason
      );
    } catch (error) {
      console.error('예약 날짜 변경 실패:', error);
      throw error;
    }
  }

  // 예약 인원 변경 간편 함수
  async changeReservationGuests(reservationId, customerPhone, newGuestCount, reason = '인원 변경 요청') {
    try {
      const reservation = await this.getReservationById(reservationId);
      if (!reservation) {
        throw new Error('예약을 찾을 수 없습니다.');
      }
      
      // 새로운 인원수로 가격 재계산
      const newPrice = await calculateTotalPriceWithGuests(
        reservation.sku_code, 
        reservation.reservation_date, 
        newGuestCount
      );
      
      const newData = {
        guest_count: newGuestCount,
        total_price: newPrice
      };
      
      return await this.createModificationRequest(
        reservationId,
        'change_guests',
        customerPhone,
        newData,
        reason
      );
    } catch (error) {
      console.error('예약 인원 변경 실패:', error);
      throw error;
    }
  }

  // 예약 정보 조회 헬퍼
  async getReservationById(reservationId) {
    try {
      const { data, error } = await supabase
        .from('reservations')
        .select('*')
        .eq('id', reservationId)
        .single();
      
      if (error) throw error;
      return data;
    } catch (error) {
      console.error('예약 조회 실패:', error);
      return null;
    }
  }

  // 변경 타입별 한글 이름
  getModificationTypeName(type) {
    const typeNames = {
      'change_date': '날짜 변경',
      'change_time': '시간 변경', 
      'change_guests': '인원 변경',
      'cancel': '예약 취소',
      'partial_refund': '부분 환불'
    };
    return typeNames[type] || type;
  }

  // 상태별 한글 이름
  getStatusName(status) {
    const statusNames = {
      'pending': '승인 대기',
      'approved': '승인됨',
      'rejected': '거부됨',
      'processing': '처리 중',
      'completed': '완료'
    };
    return statusNames[status] || status;
  }

  // 변경 요청 통계
  async getModificationStats(dateFrom = null, dateTo = null) {
    try {
      let query = supabase
        .from('reservation_modifications')
        .select('modification_type, status, created_at');

      if (dateFrom) {
        query = query.gte('created_at', dateFrom);
      }
      if (dateTo) {
        query = query.lte('created_at', dateTo);
      }

      const { data, error } = await query;
      if (error) throw error;

      // 통계 계산
      const stats = {
        total: data.length,
        pending: data.filter(d => d.status === 'pending').length,
        approved: data.filter(d => d.status === 'approved').length,
        rejected: data.filter(d => d.status === 'rejected').length,
        completed: data.filter(d => d.status === 'completed').length,
        cancel: data.filter(d => d.modification_type === 'cancel').length,
        change_date: data.filter(d => d.modification_type === 'change_date').length,
        change_guests: data.filter(d => d.modification_type === 'change_guests').length
      };

      return stats;
    } catch (error) {
      console.error('변경 요청 통계 조회 실패:', error);
      throw error;
    }
  }

  // 테스트 함수
  async testModificationSystem(reservationId) {
    try {
      const { data, error } = await supabase.rpc('test_modification_system', {
        p_reservation_id: reservationId
      });
      
      if (error) throw error;
      return data;
    } catch (error) {
      console.error('변경 시스템 테스트 실패:', error);
      throw error;
    }
  }
}

// ReservationModificationService 인스턴스 생성 및 초기화
const reservationModificationService = new ReservationModificationService();

// 전역 함수로 노출
async function getCancellationPolicies(isActive = true) {
  if (!reservationModificationService.isInitialized) {
    await reservationModificationService.initialize();
  }
  return reservationModificationService.getCancellationPolicies(isActive);
}

async function getApplicableCancellationPolicy(reservationId) {
  if (!reservationModificationService.isInitialized) {
    await reservationModificationService.initialize();
  }
  return reservationModificationService.getApplicableCancellationPolicy(reservationId);
}

async function calculateRefundAmount(reservationId, cancellationDate = null) {
  if (!reservationModificationService.isInitialized) {
    await reservationModificationService.initialize();
  }
  return reservationModificationService.calculateRefundAmount(reservationId, cancellationDate);
}

async function canModifyReservation(reservationId, modificationType = 'change_date') {
  if (!reservationModificationService.isInitialized) {
    await reservationModificationService.initialize();
  }
  return reservationModificationService.canModifyReservation(reservationId, modificationType);
}

async function getAvailableModificationOptions(reservationId, newDate = null) {
  if (!reservationModificationService.isInitialized) {
    await reservationModificationService.initialize();
  }
  return reservationModificationService.getAvailableModificationOptions(reservationId, newDate);
}

async function createModificationRequest(reservationId, modificationType, customerPhone, newData = null, reason = null) {
  if (!reservationModificationService.isInitialized) {
    await reservationModificationService.initialize();
  }
  return reservationModificationService.createModificationRequest(reservationId, modificationType, customerPhone, newData, reason);
}

async function processModificationRequest(modificationId, action, adminNotes = null, processedBy = 'admin') {
  if (!reservationModificationService.isInitialized) {
    await reservationModificationService.initialize();
  }
  return reservationModificationService.processModificationRequest(modificationId, action, adminNotes, processedBy);
}

async function getCustomerModifications(customerPhone, limit = 10) {
  if (!reservationModificationService.isInitialized) {
    await reservationModificationService.initialize();
  }
  return reservationModificationService.getCustomerModifications(customerPhone, limit);
}

async function getAllModificationRequests(status = null, limit = 50) {
  if (!reservationModificationService.isInitialized) {
    await reservationModificationService.initialize();
  }
  return reservationModificationService.getAllModificationRequests(status, limit);
}

async function getModificationRequestDetails(modificationId) {
  if (!reservationModificationService.isInitialized) {
    await reservationModificationService.initialize();
  }
  return reservationModificationService.getModificationRequestDetails(modificationId);
}

async function cancelReservation(reservationId, customerPhone, reason = '고객 요청') {
  if (!reservationModificationService.isInitialized) {
    await reservationModificationService.initialize();
  }
  return reservationModificationService.cancelReservation(reservationId, customerPhone, reason);
}

async function changeReservationDate(reservationId, customerPhone, newDate, newSkuCode = null, reason = '날짜 변경 요청') {
  if (!reservationModificationService.isInitialized) {
    await reservationModificationService.initialize();
  }
  return reservationModificationService.changeReservationDate(reservationId, customerPhone, newDate, newSkuCode, reason);
}

async function changeReservationGuests(reservationId, customerPhone, newGuestCount, reason = '인원 변경 요청') {
  if (!reservationModificationService.isInitialized) {
    await reservationModificationService.initialize();
  }
  return reservationModificationService.changeReservationGuests(reservationId, customerPhone, newGuestCount, reason);
}

async function getModificationStats(dateFrom = null, dateTo = null) {
  if (!reservationModificationService.isInitialized) {
    await reservationModificationService.initialize();
  }
  return reservationModificationService.getModificationStats(dateFrom, dateTo);
}

async function testModificationSystem(reservationId) {
  if (!reservationModificationService.isInitialized) {
    await reservationModificationService.initialize();
  }
  return reservationModificationService.testModificationSystem(reservationId);
}

// Phase 3.3: 예약 변경/취소 시스템 함수 노출
window.reservationModificationService = reservationModificationService;
window.getCancellationPolicies = getCancellationPolicies;
window.getApplicableCancellationPolicy = getApplicableCancellationPolicy;
window.calculateRefundAmount = calculateRefundAmount;
window.canModifyReservation = canModifyReservation;
window.getAvailableModificationOptions = getAvailableModificationOptions;
window.createModificationRequest = createModificationRequest;
window.processModificationRequest = processModificationRequest;
window.getCustomerModifications = getCustomerModifications;
window.getAllModificationRequests = getAllModificationRequests;
window.getModificationRequestDetails = getModificationRequestDetails;
window.cancelReservation = cancelReservation;
window.changeReservationDate = changeReservationDate;
window.changeReservationGuests = changeReservationGuests;
window.getModificationStats = getModificationStats;
window.testModificationSystem = testModificationSystem;