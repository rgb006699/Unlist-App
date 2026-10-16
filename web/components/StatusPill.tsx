import {
  Circle,
  CircleCheck,
  Clock,
  Eye,
  Globe,
  IdCard,
  Mail,
  Mailbox,
  Phone,
  Send,
  TriangleAlert,
  type LucideIcon,
} from "lucide-react";
import type { Method, ViewStatus } from "../../shared/types";
import { METHOD_LABEL, STATUS_LABEL } from "../labels";

export const STATUS_ICON: Record<ViewStatus, LucideIcon> = {
  not_checked: Circle,
  found: Eye,
  request_sent: Send,
  removed: CircleCheck,
  relisted: TriangleAlert,
  due: Clock,
};

export const METHOD_ICON: Record<Method, LucideIcon> = {
  web_form: Globe,
  email: Mail,
  phone: Phone,
  mail: Mailbox,
  id_upload: IdCard,
};

export function StatusPill({ status }: { status: ViewStatus }) {
  const Icon = STATUS_ICON[status];
  return (
    <span className={`pill pill-${status}`}>
      <Icon size={14} strokeWidth={2.25} aria-hidden="true" />
      {STATUS_LABEL[status]}
    </span>
  );
}

export function MethodTag({ method }: { method: Method }) {
  const Icon = METHOD_ICON[method];
  return (
    <span className="method">
      <Icon size={15} aria-hidden="true" />
      {METHOD_LABEL[method]}
    </span>
  );
}
