// 커스텀 캘린더 JavaScript (orig: 문자열 인코딩 손상 복구 버전)

class CustomCalendar {
  constructor() {
    this.currentDate = new Date();
    this.selectedDate = null;
    this.today = new Date();

    // orig: monthNames 손상 → 복구
    this.monthNames = [
      '1월', '2월', '3월', '4월', '5월', '6월',
      '7월', '8월', '9월', '10월', '11월', '12월'
    ];

    this.init();
  }

  init() {
    this.bindEvents();
    this.render();
    this.setupOutsideClick();
  }

  bindEvents() {
    const pickerBtn = document.getElementById('datePickerBtn');
    const prevBtn = document.getElementById('prevMonth');
    const nextBtn = document.getElementById('nextMonth');
    if (pickerBtn) {
      pickerBtn.addEventListener('click', (e) => {
        e.stopPropagation();
        this.toggleCalendar();
      });
    }
    if (prevBtn) prevBtn.addEventListener('click', () => this.previousMonth());
    if (nextBtn) nextBtn.addEventListener('click', () => this.nextMonth());
  }

  setupOutsideClick() {
    document.addEventListener('click', (e) => {
      const calendar = document.getElementById('calendarPopup');
      const datePickerBtn = document.getElementById('datePickerBtn');
      if (!calendar || !datePickerBtn) return;
      if (!calendar.contains(e.target) && !datePickerBtn.contains(e.target)) {
        this.closeCalendar();
      }
    });
  }

  toggleCalendar() {
    const popup = document.getElementById('calendarPopup');
    if (!popup) return;
    const isVisible = popup.style.display === 'block';
    if (isVisible) this.closeCalendar();
    else this.openCalendar();
  }

  openCalendar() {
    const popup = document.getElementById('calendarPopup');
    if (!popup) return;
    popup.style.display = 'block';
    this.render();
  }

  closeCalendar() {
    const popup = document.getElementById('calendarPopup');
    if (popup) popup.style.display = 'none';
  }

  previousMonth() {
    this.currentDate.setMonth(this.currentDate.getMonth() - 1);
    this.render();
  }

  nextMonth() {
    this.currentDate.setMonth(this.currentDate.getMonth() + 1);
    this.render();
  }

  render() {
    this.renderHeader();
    this.renderDays();
  }

  renderHeader() {
    const title = document.getElementById('calendarTitle');
    if (!title) return;
    const year = this.currentDate.getFullYear();
    const month = this.currentDate.getMonth();
    // orig: `${year}??${this.monthNames[month]}` → 복구
    title.textContent = `${year}년 ${this.monthNames[month]}`;
  }

  renderDays() {
    const daysContainer = document.getElementById('calendarDays');
    if (!daysContainer) return;
    daysContainer.innerHTML = '';

    const year = this.currentDate.getFullYear();
    const month = this.currentDate.getMonth();
    const firstDay = new Date(year, month, 1);
    const startDate = new Date(firstDay);
    startDate.setDate(startDate.getDate() - firstDay.getDay());

    for (let i = 0; i < 42; i++) {
      const date = new Date(startDate);
      date.setDate(startDate.getDate() + i);
      const dayElement = this.createDayElement(date, month);
      daysContainer.appendChild(dayElement);
    }
  }

  createDayElement(date, currentMonth) {
    const dayDiv = document.createElement('div');
    dayDiv.className = 'calendar-day';
    dayDiv.textContent = date.getDate();

    if (date.getMonth() !== currentMonth) dayDiv.classList.add('other-month');

    const isToday =
      date.getFullYear() === this.today.getFullYear() &&
      date.getMonth() === this.today.getMonth() &&
      date.getDate() === this.today.getDate();
    if (isToday) dayDiv.classList.add('today');

    const isPast = date < new Date(this.today.getFullYear(), this.today.getMonth(), this.today.getDate());
    if (isPast) dayDiv.classList.add('disabled');

    dayDiv.addEventListener('click', () => {
      if (isPast) return;
      this.selectDate(date);
    });
    return dayDiv;
  }

  selectDate(date) {
    this.selectedDate = date;
    const hiddenInput = document.getElementById('reservation_date');
    const selectedText = document.getElementById('selectedDateText');
    if (hiddenInput) hiddenInput.value = this.formatDateForAPI(date);
    if (selectedText) selectedText.textContent = this.getSelectedDateString();
    this.closeCalendar();
    // 예약 가능한 상품 로드 (있다면)
    this.loadAvailableProducts(date);
  }

  formatDateForAPI(date) {
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    return `${year}-${month}-${day}`;
  }

  getSelectedDate() {
    return this.selectedDate;
  }

  getSelectedDateString() {
    if (!this.selectedDate) return '';
    const y = this.selectedDate.getFullYear();
    const m = this.selectedDate.getMonth() + 1;
    const d = this.selectedDate.getDate();
    const weekday = this.getWeekdayName(this.selectedDate.getDay());
    return `${y}년 ${m}월 ${d}일 (${weekday})`;
  }

  getWeekdayName(idx) {
    const days = ['일', '월', '화', '수', '목', '금', '토'];
    return days[idx] || '';
  }

  // 예약 가능한 상품 로드 (supabase-config.js의 getAvailableProductsByDate 사용)
  async loadAvailableProducts(date) {
    if (typeof getAvailableProductsByDate !== 'function') return;
    try {
      const dateStr = this.formatDateForAPI(date);
      const result = await getAvailableProductsByDate(dateStr);
      if (result.success) this.displayAvailableProducts(result.data, date);
      else this.displayAvailableProducts([], date);
    } catch (err) {
      console.error('예약 가능한 상품 조회 오류:', err);
      this.displayAvailableProducts([], date);
    }
  }

  displayAvailableProducts(products, selectedDate) {
    let container = document.getElementById('availableProductsContainer');
    if (!container) {
      this.createAvailableProductsContainer();
      container = document.getElementById('availableProductsContainer');
    }
    const year = selectedDate.getFullYear();
    const month = selectedDate.getMonth() + 1;
    const day = selectedDate.getDate();
    const weekday = this.getWeekdayName(selectedDate.getDay());

    if (!products || products.length === 0) {
      container.innerHTML = `
        <div class="available-products-section">
          <div class="date-header">
            <!-- orig: 손상된 날짜 표기 복구 -->
            <h3>${year}년 ${month}월 ${day}일 (${weekday}) 예약 현황</h3>
          </div>
          <div class="no-products">
            <div class="no-products-icon">🗓️</div>
            <p>해당 날짜에 예약 가능한 상품이 없습니다.</p>
            <small>다른 날짜를 선택해보세요.</small>
          </div>
        </div>
     `;
    } else {
      const productsHTML = products
        .map(
          (product) => `
        <div class="product-item" data-product-id="${product.id}">
          <div class="product-time">
            ${this.formatTimeRange(product.start_time, product.end_time)}
          </div>
          <div class="product-info">
            <h4>${product.display_name || product.product_name}</h4>
            <p class="product-description">${product.description || '제품 설명이 없습니다.'}</p>
            <!-- orig: 가격 보간 손상 → 복구 -->
            <div class="product-price">₩${Number(product.price || 0).toLocaleString()}</div>
          </div>
          <div class="product-actions">
            <button class="select-product-btn" onclick="selectProduct('${product.id}', '${product.display_name || product.product_name}')">선택하기</button>
          </div>
        </div>`
        )
        .join('');

      container.innerHTML = `
        <div class="available-products-section">
          <div class="date-header">
            <h3>${year}년 ${month}월 ${day}일 (${weekday}) 예약 가능한 상품</h3>
            <span class="product-count">${products.length}개 상품 이용 가능</span>
          </div>
          <div class="products-list">${productsHTML}</div>
        </div>
      `;
    }

    container.style.display = 'block';
    container.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
  }

  createAvailableProductsContainer() {
    const formContainer = document.querySelector('.form-container');
    if (formContainer) {
      const container = document.createElement('div');
      container.id = 'availableProductsContainer';
      container.style.display = 'none';
      formContainer.parentNode.insertBefore(container, formContainer.nextSibling);
    }
  }

  formatTimeRange(startTime, endTime) {
    const formatTime = (timeString) => {
      const [hours, minutes] = String(timeString).split(':');
      const hour = parseInt(hours, 10);
      const ampm = hour >= 12 ? '오후' : '오전';
      const displayHour = hour > 12 ? hour - 12 : hour === 0 ? 12 : hour;
      return `${ampm} ${displayHour}:${minutes}`;
    };
    return `${formatTime(startTime)} - ${formatTime(endTime)}`;
  }

  setDate(date) {
    this.currentDate = new Date(date);
    this.render();
  }
}

// 전역 인스턴스 생성
let customCalendar;
document.addEventListener('DOMContentLoaded', function () {
  if (document.getElementById('datePickerBtn')) {
    customCalendar = new CustomCalendar();
    window.getSelectedDate = () => customCalendar.getSelectedDate();
    window.getSelectedDateString = () => customCalendar.getSelectedDateString();
    window.setCalendarDate = (date) => customCalendar.setDate(date);
  }
});

// 유틸리티: 오늘 이후만 선택 가능하도록 오늘 기준 갱신
function setMinDateToToday() {
  if (customCalendar) {
    customCalendar.today = new Date();
    customCalendar.render();
  }
}

