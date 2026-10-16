// Unlist "Fill my details": puts the owner's details into empty form fields on
// the page they are looking at. It never clicks, submits, or touches CAPTCHAs,
// and never overwrites a field that already has text.
//
// unlistFill({ values: { firstName, lastName, fullName, email, phone, street,
//              city, state, zip }, selectors: { field: cssSelector },
//              stateName: "Texas" }) -> { filled: n, fields: [...] }

window.unlistFill = function (payload) {
  var values = payload.values || {};
  var selectors = payload.selectors || {};
  var stateName = (payload.stateName || "").toLowerCase();
  var filled = [];

  var AUTOCOMPLETE = {
    "given-name": "firstName", "family-name": "lastName", "name": "fullName",
    "email": "email", "tel": "phone", "tel-national": "phone",
    "street-address": "street", "address-line1": "street",
    "address-level2": "city", "address-level1": "state", "postal-code": "zip"
  };

  // Checked in this order, so "email address" is an email, not a street.
  var KEYWORDS = [
    ["email", /\b(e-?mail)\b/],
    ["phone", /\b(phone|tel|telephone|mobile|cell)\b/],
    ["firstName", /\b(first|fname|given|forename)\b/],
    ["lastName", /\b(last|lname|surname|family)\b/],
    ["zip", /\b(zip|postal|postcode|zipcode)\b/],
    ["city", /\b(city|town)\b/],
    ["state", /\b(state|province|region)\b/],
    ["street", /\b(street|address ?1|address line ?1|addr1|address)\b/],
    ["fullName", /\b(full ?name|your name|name)\b/]
  ];

  function isFillable(el) {
    if (el.disabled || el.readOnly) return false;
    var tag = el.tagName.toLowerCase();
    if (tag === "input") {
      var t = (el.getAttribute("type") || "text").toLowerCase();
      if (["hidden", "password", "checkbox", "radio", "file", "submit", "button", "image", "reset"].indexOf(t) >= 0) return false;
    }
    if (/captcha/i.test((el.name || "") + " " + (el.id || "") + " " + (el.className || ""))) return false;
    var style = window.getComputedStyle(el);
    if (style.display === "none" || style.visibility === "hidden") return false;
    return true;
  }

  function isEmpty(el) {
    if (el.tagName.toLowerCase() === "select") return !el.value;
    return !el.value || !el.value.trim();
  }

  function labelText(el) {
    var parts = [];
    if (el.labels) for (var i = 0; i < el.labels.length; i++) parts.push(el.labels[i].textContent || "");
    var labelledBy = el.getAttribute("aria-labelledby");
    if (labelledBy) labelledBy.split(/\s+/).forEach(function (id) {
      var l = document.getElementById(id); if (l) parts.push(l.textContent || "");
    });
    return parts.join(" ");
  }

  // Words describing the field, with camelCase, _ and - split into spaces.
  function describe(el) {
    var raw = [el.name, el.id, el.getAttribute("placeholder"), el.getAttribute("aria-label"), labelText(el)]
      .filter(Boolean).join(" ");
    return raw.replace(/([a-z])([A-Z])/g, "$1 $2").replace(/[_\-.\[\]]+/g, " ").toLowerCase();
  }

  function setValue(el, value) {
    var tag = el.tagName.toLowerCase();
    if (tag === "select") {
      var want = [value.toLowerCase(), value === values.state ? stateName : ""].filter(Boolean);
      for (var i = 0; i < el.options.length; i++) {
        var o = el.options[i];
        if (want.indexOf((o.value || "").trim().toLowerCase()) >= 0 || want.indexOf((o.text || "").trim().toLowerCase()) >= 0) {
          el.value = o.value;
          break;
        }
      }
      if (isEmpty(el)) return false;
    } else {
      // Use the native setter so frameworks that track the value notice it.
      var proto = tag === "textarea" ? HTMLTextAreaElement.prototype : HTMLInputElement.prototype;
      var setter = Object.getOwnPropertyDescriptor(proto, "value").set;
      setter.call(el, value);
    }
    el.dispatchEvent(new Event("input", { bubbles: true }));
    el.dispatchEvent(new Event("change", { bubbles: true }));
    return true;
  }

  function fill(el, field) {
    var value = values[field];
    if (!value || !isFillable(el) || !isEmpty(el)) return;
    if (setValue(el, value)) filled.push(field);
  }

  // 1. Per-site selectors.
  var bySelector = {};
  Object.keys(selectors).forEach(function (field) {
    var el = null;
    try { el = document.querySelector(selectors[field]); } catch (e) { el = null; }
    if (el) { bySelector[field] = true; fill(el, field); }
  });

  // 2. Generic matching.
  var fields = Array.prototype.slice.call(document.querySelectorAll("input, select, textarea")).filter(isFillable);
  var hasSplitName = fields.some(function (el) {
    var ac = (el.getAttribute("autocomplete") || "").toLowerCase();
    return ac === "given-name" || ac === "family-name" || /\b(first|fname|given|last|lname|surname)\b/.test(describe(el));
  });

  fields.forEach(function (el) {
    var field = AUTOCOMPLETE[(el.getAttribute("autocomplete") || "").toLowerCase().trim()];
    if (!field) {
      var type = (el.getAttribute("type") || "").toLowerCase();
      if (type === "email") field = "email";
      else if (type === "tel") field = "phone";
    }
    if (!field) {
      var words = describe(el);
      for (var i = 0; i < KEYWORDS.length; i++) {
        if (KEYWORDS[i][1].test(words)) { field = KEYWORDS[i][0]; break; }
      }
    }
    if (!field || bySelector[field]) return;
    if (field === "fullName" && hasSplitName) return;
    fill(el, field);
  });

  return { filled: filled.length, fields: filled };
};
