import React from 'react'
import s from './PatrolDetailPanel.module.css'

// ── Officer roster per patrol unit ────────────────────────────────────────────
const PATROL_OFFICERS = {
  P1:  [
    { name: 'SI Rajesh Kumar',  badge: 'TN-2341', rank: 'Sub Inspector'       },
    { name: 'PC Muthu Selvam',  badge: 'TN-4521', rank: 'Police Constable'    },
    { name: 'PC Anitha Devi',   badge: 'TN-4890', rank: 'Police Constable'    },
  ],
  P2:  [
    { name: 'SI Priya Nair',    badge: 'TN-2287', rank: 'Sub Inspector'       },
    { name: 'PC Suresh Babu',   badge: 'TN-4102', rank: 'Police Constable'    },
  ],
  P3:  [
    { name: 'ASI Karthik Raja', badge: 'TN-3341', rank: 'Asst Sub Inspector'  },
    { name: 'PC Lakshmi S',     badge: 'TN-4667', rank: 'Police Constable'    },
    { name: 'PC Dinesh M',      badge: 'TN-4701', rank: 'Police Constable'    },
  ],
  P4:  [
    { name: 'SI Meena Kumari',  badge: 'TN-2198', rank: 'Sub Inspector'       },
    { name: 'PC Venkat R',      badge: 'TN-4334', rank: 'Police Constable'    },
  ],
  P5:  [
    { name: 'ASI Balamurugan',  badge: 'TN-3109', rank: 'Asst Sub Inspector'  },
    { name: 'PC Saranya T',     badge: 'TN-4556', rank: 'Police Constable'    },
    { name: 'PC Ravi Kumar',    badge: 'TN-4812', rank: 'Police Constable'    },
  ],
  P6:  [
    { name: 'SI Deepa Raj',     badge: 'TN-2445', rank: 'Sub Inspector'       },
    { name: 'PC Senthil K',     badge: 'TN-4923', rank: 'Police Constable'    },
  ],
  P7:  [
    { name: 'ASI Murugesan',    badge: 'TN-3267', rank: 'Asst Sub Inspector'  },
    { name: 'PC Kavitha S',     badge: 'TN-4445', rank: 'Police Constable'    },
    { name: 'PC Prakash N',     badge: 'TN-4678', rank: 'Police Constable'    },
  ],
  P8:  [
    { name: 'SI Tamil Selvi',   badge: 'TN-2356', rank: 'Sub Inspector'       },
    { name: 'PC Ganesh R',      badge: 'TN-4234', rank: 'Police Constable'    },
  ],
  P9:  [
    { name: 'ASI Sundaram P',   badge: 'TN-3445', rank: 'Asst Sub Inspector'  },
    { name: 'PC Vijaya L',      badge: 'TN-4789', rank: 'Police Constable'    },
    { name: 'PC Arjun D',       badge: 'TN-4901', rank: 'Police Constable'    },
  ],
  P10: [
    { name: 'SI Nandhini K',    badge: 'TN-2512', rank: 'Sub Inspector'       },
    { name: 'PC Manoj T',       badge: 'TN-4345', rank: 'Police Constable'    },
  ],
  P11: [
    { name: 'SI Kavya Rajan',   badge: 'TN-2601', rank: 'Sub Inspector'       },
    { name: 'PC Dinesh S',      badge: 'TN-5001', rank: 'Police Constable'    },
  ],
  P12: [
    { name: 'ASI Raman K',      badge: 'TN-3501', rank: 'Asst Sub Inspector'  },
    { name: 'PC Preethi M',     badge: 'TN-5102', rank: 'Police Constable'    },
    { name: 'PC Arun T',        badge: 'TN-5203', rank: 'Police Constable'    },
  ],
  P13: [
    { name: 'SI Vimal Kumar',   badge: 'TN-2701', rank: 'Sub Inspector'       },
    { name: 'PC Sangeetha R',   badge: 'TN-5304', rank: 'Police Constable'    },
  ],
  P14: [
    { name: 'ASI Padmavathi',   badge: 'TN-3601', rank: 'Asst Sub Inspector'  },
    { name: 'PC Karthi N',      badge: 'TN-5405', rank: 'Police Constable'    },
    { name: 'PC Divya S',       badge: 'TN-5506', rank: 'Police Constable'    },
  ],
  P15: [
    { name: 'SI Arulraj M',     badge: 'TN-2801', rank: 'Sub Inspector'       },
    { name: 'PC Nithya K',      badge: 'TN-5607', rank: 'Police Constable'    },
  ],
  P16: [
    { name: 'ASI Selvi P',      badge: 'TN-3701', rank: 'Asst Sub Inspector'  },
    { name: 'PC Vijay R',       badge: 'TN-5708', rank: 'Police Constable'    },
    { name: 'PC Mala D',        badge: 'TN-5809', rank: 'Police Constable'    },
  ],
  P17: [
    { name: 'SI Ganesh B',      badge: 'TN-2901', rank: 'Sub Inspector'       },
    { name: 'PC Rekha S',       badge: 'TN-5910', rank: 'Police Constable'    },
  ],
  P18: [
    { name: 'ASI Nithyanand',   badge: 'TN-3801', rank: 'Asst Sub Inspector'  },
    { name: 'PC Tamilarasi',    badge: 'TN-6001', rank: 'Police Constable'    },
    { name: 'PC Surya M',       badge: 'TN-6102', rank: 'Police Constable'    },
  ],
  P19: [
    { name: 'SI Dhanalakshmi',  badge: 'TN-3001', rank: 'Sub Inspector'       },
    { name: 'PC Prasad K',      badge: 'TN-6203', rank: 'Police Constable'    },
  ],
  P20: [
    { name: 'ASI Murugan S',    badge: 'TN-3901', rank: 'Asst Sub Inspector'  },
    { name: 'PC Geetha R',      badge: 'TN-6304', rank: 'Police Constable'    },
    { name: 'PC Aakash V',      badge: 'TN-6405', rank: 'Police Constable'    },
  ],
}

// Mock contact numbers per unit
const PATROL_CONTACTS = {
  P1:  '+914428123401', P2:  '+914428123402', P3:  '+914428123403',
  P4:  '+914428123404', P5:  '+914428123405', P6:  '+914428123406',
  P7:  '+914428123407', P8:  '+914428123408', P9:  '+914428123409',
  P10: '+914428123410', P11: '+914428123411', P12: '+914428123412',
  P13: '+914428123413', P14: '+914428123414', P15: '+914428123415',
  P16: '+914428123416', P17: '+914428123417', P18: '+914428123418',
  P19: '+914428123419', P20: '+914428123420',
}

const STATUS_COLOR = {
  Patrolling: '#3b82f6',
  Responding: '#ef4444',
  AtScene:    '#22c55e',
}

/**
 * PatrolDetailPanel — read-only detail for one live unit.
 * Props:
 *   patrol  — normalised row from useLivePatrols (or null when closed)
 *   onClose — () => void
 */
export default function PatrolDetailPanel({ patrol, onClose }) {
  const isOpen = !!patrol

  const officers  = patrol ? (PATROL_OFFICERS[patrol.id] ?? []) : []
  const contact   = patrol ? (PATROL_CONTACTS[patrol.id] ?? '+914428123400') : ''
  const statusCol = patrol ? (STATUS_COLOR[patrol.status] ?? '#3b82f6') : '#3b82f6'

  return (
    <div className={`${s.panel} ${isOpen ? s.open : ''}`} role="dialog" aria-modal="true">
      {patrol && (
        <>
          {/* Header */}
          <div className={s.hdr}>
            <div className={s.hdrLeft}>
              <div className={s.unitName}>{patrol.name}</div>
              <div className={s.vehicle}>{patrol.vehicle}</div>
            </div>
            <button className={s.closeBtn} onClick={onClose} aria-label="Close panel">×</button>
          </div>

          {/* Status badge */}
          <div className={s.statusRow}>
            <span
              className={`${s.statusBadge} ${patrol.status === 'Responding' ? s.pulseBadge : ''}`}
              style={{ background: `${statusCol}22`, border: `1px solid ${statusCol}55`, color: statusCol }}
            >
              {patrol.status === 'Patrolling' ? '● Patrolling'
                : patrol.status === 'Responding' ? '● Responding'
                : '● At Scene'}
            </span>
          </div>

          {/* Coordinates */}
          <div className={s.section}>
            <div className={s.sectionLabel}>CURRENT POSITION</div>
            <div className={s.coords}>
              {patrol.position
                ? `${Number(patrol.position.lat).toFixed(4)}°N, ${Number(patrol.position.lng).toFixed(4)}°E`
                : '—'}
              {patrol.status === 'Responding' && patrol.eta_seconds != null && (
                <span> · ETA {Math.max(0, Math.round(patrol.eta_seconds))}s</span>
              )}
            </div>
          </div>

          {/* Officers */}
          <div className={s.section}>
            <div className={s.sectionLabel}>OFFICERS ON DUTY</div>
            <div className={s.officerList}>
              {officers.map(o => (
                <div key={o.badge} className={s.officer}>
                  <div className={s.officerAvatar}>{o.name.charAt(0)}</div>
                  <div className={s.officerInfo}>
                    <div className={s.officerName}>{o.name}</div>
                    <div className={s.officerMeta}>{o.rank} · {o.badge}</div>
                  </div>
                </div>
              ))}
            </div>
          </div>

          {/* Actions */}
          <div className={s.section}>
            <div className={s.sectionLabel}>CONTACT</div>
            {/* Dispatch is automatic — POST /sos/live diverts the nearest free
                unit in the same call — so there is no manual dispatch button. */}
            <div className={s.actions}>
              <a href={`tel:${contact}`} className={s.callBtn}>
                📞 Call Unit
              </a>
            </div>
          </div>
        </>
      )}
    </div>
  )
}
