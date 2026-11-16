
export type Json = string | number | boolean | null | { [key: string]: Json | undefined } | Json[]

export type Database = {
  
  "public": {
          Tables: {
            "athlete_profiles": {
                  Row: {
                    "athlete_id": string,"created_at": string,"height_cm": number | null,"long_term_goal": string | null,"sex": string | null,"short_term_goal": string | null,"updated_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "athlete_id": string,"created_at"?: string,"height_cm"?: number | null,"long_term_goal"?: string | null,"sex"?: string | null,"short_term_goal"?: string | null,"updated_at"?: string
                  }
                  Update: {
                    "athlete_id"?: string,"created_at"?: string,"height_cm"?: number | null,"long_term_goal"?: string | null,"sex"?: string | null,"short_term_goal"?: string | null,"updated_at"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "athlete_profiles_athlete_id_fkey"
      columns: ["athlete_id"]
isOneToOne: true
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    }
                  ]
                },"day_exercises": {
                  Row: {
                    "athlete_id": string | null,"created_at": string,"exercise_id": string,"id": string,"is_template": boolean,"notes": string | null,"position": number,"trainer_id": string,"training_day_id": string,"updated_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "athlete_id"?: string | null,"created_at"?: string,"exercise_id": string,"id"?: string,"is_template"?: never,"notes"?: string | null,"position"?: number,"trainer_id": string,"training_day_id": string,"updated_at"?: string
                  }
                  Update: {
                    "athlete_id"?: string | null,"created_at"?: string,"exercise_id"?: string,"id"?: string,"is_template"?: never,"notes"?: string | null,"position"?: number,"trainer_id"?: string,"training_day_id"?: string,"updated_at"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "day_exercises_athlete_id_fkey"
      columns: ["athlete_id"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "day_exercises_exercise_id_trainer_id_fkey"
      columns: ["exercise_id","trainer_id"]
isOneToOne: false
      referencedRelation: "exercises"
      referencedColumns: ["id","trainer_id"]
    },{
      foreignKeyName: "day_exercises_trainer_id_fkey"
      columns: ["trainer_id"]
isOneToOne: false
      referencedRelation: "trainers"
      referencedColumns: ["profile_id"]
    },{
      foreignKeyName: "day_exercises_training_day_id_athlete_id_fkey"
      columns: ["training_day_id","athlete_id"]
isOneToOne: false
      referencedRelation: "training_days"
      referencedColumns: ["id","athlete_id"]
    },{
      foreignKeyName: "day_exercises_training_day_id_template_fkey"
      columns: ["training_day_id","trainer_id","is_template"]
isOneToOne: false
      referencedRelation: "training_days"
      referencedColumns: ["id","trainer_id","is_template"]
    }
                  ]
                },"exercise_prescriptions": {
                  Row: {
                    "athlete_id": string | null,"created_at": string,"day_exercise_id": string,"from_week": number,"id": string,"is_template": boolean,"trainer_id": string,"updated_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "athlete_id"?: string | null,"created_at"?: string,"day_exercise_id": string,"from_week": number,"id"?: string,"is_template"?: never,"trainer_id": string,"updated_at"?: string
                  }
                  Update: {
                    "athlete_id"?: string | null,"created_at"?: string,"day_exercise_id"?: string,"from_week"?: number,"id"?: string,"is_template"?: never,"trainer_id"?: string,"updated_at"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "exercise_prescriptions_athlete_id_fkey"
      columns: ["athlete_id"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "exercise_prescriptions_day_exercise_id_athlete_id_fkey"
      columns: ["day_exercise_id","athlete_id"]
isOneToOne: false
      referencedRelation: "day_exercises"
      referencedColumns: ["id","athlete_id"]
    },{
      foreignKeyName: "exercise_prescriptions_day_exercise_id_template_fkey"
      columns: ["day_exercise_id","trainer_id","is_template"]
isOneToOne: false
      referencedRelation: "day_exercises"
      referencedColumns: ["id","trainer_id","is_template"]
    },{
      foreignKeyName: "exercise_prescriptions_trainer_id_fkey"
      columns: ["trainer_id"]
isOneToOne: false
      referencedRelation: "trainers"
      referencedColumns: ["profile_id"]
    }
                  ]
                },"exercises": {
                  Row: {
                    "archived_at": string | null,"created_at": string,"id": string,"movement_category_id": string | null,"name": string,"source": string,"source_ref": string | null,"technique_notes": string | null,"trainer_id": string,"updated_at": string,"video_url": string | null
                  }
                  ComputedFields: never
                  Insert: {
                    "archived_at"?: string | null,"created_at"?: string,"id"?: string,"movement_category_id"?: string | null,"name": string,"source"?: string,"source_ref"?: string | null,"technique_notes"?: string | null,"trainer_id": string,"updated_at"?: string,"video_url"?: string | null
                  }
                  Update: {
                    "archived_at"?: string | null,"created_at"?: string,"id"?: string,"movement_category_id"?: string | null,"name"?: string,"source"?: string,"source_ref"?: string | null,"technique_notes"?: string | null,"trainer_id"?: string,"updated_at"?: string,"video_url"?: string | null
                  }
                  Relationships: [
                    {
      foreignKeyName: "exercises_movement_category_id_trainer_id_fkey"
      columns: ["movement_category_id","trainer_id"]
isOneToOne: false
      referencedRelation: "movement_categories"
      referencedColumns: ["id","trainer_id"]
    },{
      foreignKeyName: "exercises_trainer_id_fkey"
      columns: ["trainer_id"]
isOneToOne: false
      referencedRelation: "trainers"
      referencedColumns: ["profile_id"]
    }
                  ]
                },"food_swaps": {
                  Row: {
                    "archived_at": string | null,"created_at": string,"factor": number,"from_food_id": string,"id": string,"note": string | null,"nutrient_group": string,"to_food_id": string,"trainer_id": string,"updated_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "archived_at"?: string | null,"created_at"?: string,"factor": number,"from_food_id": string,"id"?: string,"note"?: string | null,"nutrient_group": string,"to_food_id": string,"trainer_id": string,"updated_at"?: string
                  }
                  Update: {
                    "archived_at"?: string | null,"created_at"?: string,"factor"?: number,"from_food_id"?: string,"id"?: string,"note"?: string | null,"nutrient_group"?: string,"to_food_id"?: string,"trainer_id"?: string,"updated_at"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "food_swaps_from_food_id_trainer_id_fkey"
      columns: ["from_food_id","trainer_id"]
isOneToOne: false
      referencedRelation: "foods"
      referencedColumns: ["id","trainer_id"]
    },{
      foreignKeyName: "food_swaps_to_food_id_trainer_id_fkey"
      columns: ["to_food_id","trainer_id"]
isOneToOne: false
      referencedRelation: "foods"
      referencedColumns: ["id","trainer_id"]
    },{
      foreignKeyName: "food_swaps_trainer_id_fkey"
      columns: ["trainer_id"]
isOneToOne: false
      referencedRelation: "trainers"
      referencedColumns: ["profile_id"]
    }
                  ]
                },"foods": {
                  Row: {
                    "archived_at": string | null,"brand": string | null,"carbs_g": number,"created_at": string,"fat_g": number,"id": string,"name": string,"protein_g": number,"source": string,"source_ref": string | null,"trainer_id": string,"unit_grams": number | null,"unit_name": string | null,"updated_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "archived_at"?: string | null,"brand"?: string | null,"carbs_g": number,"created_at"?: string,"fat_g": number,"id"?: string,"name": string,"protein_g": number,"source"?: string,"source_ref"?: string | null,"trainer_id": string,"unit_grams"?: number | null,"unit_name"?: string | null,"updated_at"?: string
                  }
                  Update: {
                    "archived_at"?: string | null,"brand"?: string | null,"carbs_g"?: number,"created_at"?: string,"fat_g"?: number,"id"?: string,"name"?: string,"protein_g"?: number,"source"?: string,"source_ref"?: string | null,"trainer_id"?: string,"unit_grams"?: number | null,"unit_name"?: string | null,"updated_at"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "foods_trainer_id_fkey"
      columns: ["trainer_id"]
isOneToOne: false
      referencedRelation: "trainers"
      referencedColumns: ["profile_id"]
    }
                  ]
                },"invitations": {
                  Row: {
                    "accepted_at": string | null,"accepted_by": string | null,"created_at": string,"email": string,"expires_at": string,"id": string,"trainer_id": string,"updated_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "accepted_at"?: string | null,"accepted_by"?: string | null,"created_at"?: string,"email": string,"expires_at": string,"id"?: string,"trainer_id": string,"updated_at"?: string
                  }
                  Update: {
                    "accepted_at"?: string | null,"accepted_by"?: string | null,"created_at"?: string,"email"?: string,"expires_at"?: string,"id"?: string,"trainer_id"?: string,"updated_at"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "invitations_accepted_by_fkey"
      columns: ["accepted_by"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "invitations_trainer_id_fkey"
      columns: ["trainer_id"]
isOneToOne: false
      referencedRelation: "trainers"
      referencedColumns: ["profile_id"]
    }
                  ]
                },"mesocycles": {
                  Row: {
                    "athlete_id": string | null,"copied_from_id": string | null,"created_at": string,"id": string,"is_template": boolean,"name": string,"starts_on": string | null,"status": string,"trainer_id": string,"updated_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "athlete_id"?: string | null,"copied_from_id"?: string | null,"created_at"?: string,"id"?: string,"is_template"?: never,"name": string,"starts_on"?: string | null,"status"?: string,"trainer_id": string,"updated_at"?: string
                  }
                  Update: {
                    "athlete_id"?: string | null,"copied_from_id"?: string | null,"created_at"?: string,"id"?: string,"is_template"?: never,"name"?: string,"starts_on"?: string | null,"status"?: string,"trainer_id"?: string,"updated_at"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "mesocycles_athlete_id_fkey"
      columns: ["athlete_id"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "mesocycles_copied_from_id_trainer_id_fkey"
      columns: ["copied_from_id","trainer_id"]
isOneToOne: false
      referencedRelation: "mesocycles"
      referencedColumns: ["id","trainer_id"]
    },{
      foreignKeyName: "mesocycles_trainer_id_fkey"
      columns: ["trainer_id"]
isOneToOne: false
      referencedRelation: "trainers"
      referencedColumns: ["profile_id"]
    }
                  ]
                },"movement_categories": {
                  Row: {
                    "archived_at": string | null,"created_at": string,"id": string,"name": string,"position": number,"trainer_id": string,"updated_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "archived_at"?: string | null,"created_at"?: string,"id"?: string,"name": string,"position"?: number,"trainer_id": string,"updated_at"?: string
                  }
                  Update: {
                    "archived_at"?: string | null,"created_at"?: string,"id"?: string,"name"?: string,"position"?: number,"trainer_id"?: string,"updated_at"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "movement_categories_trainer_id_fkey"
      columns: ["trainer_id"]
isOneToOne: false
      referencedRelation: "trainers"
      referencedColumns: ["profile_id"]
    }
                  ]
                },"prescribed_sets": {
                  Row: {
                    "athlete_id": string | null,"created_at": string,"exercise_prescription_id": string,"id": string,"is_per_side": boolean,"is_template": boolean,"notes": string | null,"set_number": number,"target_effort": string | null,"target_reps_max": number,"target_reps_min": number,"target_rir_max": number | null,"target_rir_min": number | null,"technique": string | null,"trainer_id": string,"updated_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "athlete_id"?: string | null,"created_at"?: string,"exercise_prescription_id": string,"id"?: string,"is_per_side"?: boolean,"is_template"?: never,"notes"?: string | null,"set_number": number,"target_effort"?: string | null,"target_reps_max": number,"target_reps_min": number,"target_rir_max"?: number | null,"target_rir_min"?: number | null,"technique"?: string | null,"trainer_id": string,"updated_at"?: string
                  }
                  Update: {
                    "athlete_id"?: string | null,"created_at"?: string,"exercise_prescription_id"?: string,"id"?: string,"is_per_side"?: boolean,"is_template"?: never,"notes"?: string | null,"set_number"?: number,"target_effort"?: string | null,"target_reps_max"?: number,"target_reps_min"?: number,"target_rir_max"?: number | null,"target_rir_min"?: number | null,"technique"?: string | null,"trainer_id"?: string,"updated_at"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "prescribed_sets_athlete_id_fkey"
      columns: ["athlete_id"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "prescribed_sets_exercise_prescription_id_athlete_id_fkey"
      columns: ["exercise_prescription_id","athlete_id"]
isOneToOne: false
      referencedRelation: "exercise_prescriptions"
      referencedColumns: ["id","athlete_id"]
    },{
      foreignKeyName: "prescribed_sets_exercise_prescription_id_template_fkey"
      columns: ["exercise_prescription_id","trainer_id","is_template"]
isOneToOne: false
      referencedRelation: "exercise_prescriptions"
      referencedColumns: ["id","trainer_id","is_template"]
    },{
      foreignKeyName: "prescribed_sets_trainer_id_fkey"
      columns: ["trainer_id"]
isOneToOne: false
      referencedRelation: "trainers"
      referencedColumns: ["profile_id"]
    }
                  ]
                },"profiles": {
                  Row: {
                    "created_at": string,"full_name": string | null,"id": string,"locale": string,"updated_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"full_name"?: string | null,"id": string,"locale"?: string,"updated_at"?: string
                  }
                  Update: {
                    "created_at"?: string,"full_name"?: string | null,"id"?: string,"locale"?: string,"updated_at"?: string
                  }
                  Relationships: [
                    
                  ]
                },"trainer_athletes": {
                  Row: {
                    "athlete_id": string,"created_at": string,"ended_at": string | null,"id": string,"started_at": string,"trainer_id": string,"updated_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "athlete_id": string,"created_at"?: string,"ended_at"?: string | null,"id"?: string,"started_at"?: string,"trainer_id": string,"updated_at"?: string
                  }
                  Update: {
                    "athlete_id"?: string,"created_at"?: string,"ended_at"?: string | null,"id"?: string,"started_at"?: string,"trainer_id"?: string,"updated_at"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "trainer_athletes_athlete_id_fkey"
      columns: ["athlete_id"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "trainer_athletes_trainer_id_fkey"
      columns: ["trainer_id"]
isOneToOne: false
      referencedRelation: "trainers"
      referencedColumns: ["profile_id"]
    }
                  ]
                },"trainers": {
                  Row: {
                    "created_at": string,"profile_id": string,"updated_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"profile_id": string,"updated_at"?: string
                  }
                  Update: {
                    "created_at"?: string,"profile_id"?: string,"updated_at"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "trainers_profile_id_fkey"
      columns: ["profile_id"]
isOneToOne: true
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    }
                  ]
                },"training_days": {
                  Row: {
                    "athlete_id": string | null,"created_at": string,"id": string,"is_template": boolean,"kind": string,"mesocycle_id": string,"name": string,"position": number,"trainer_id": string,"updated_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "athlete_id"?: string | null,"created_at"?: string,"id"?: string,"is_template"?: never,"kind"?: string,"mesocycle_id": string,"name": string,"position"?: number,"trainer_id": string,"updated_at"?: string
                  }
                  Update: {
                    "athlete_id"?: string | null,"created_at"?: string,"id"?: string,"is_template"?: never,"kind"?: string,"mesocycle_id"?: string,"name"?: string,"position"?: number,"trainer_id"?: string,"updated_at"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "training_days_athlete_id_fkey"
      columns: ["athlete_id"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "training_days_mesocycle_id_athlete_id_fkey"
      columns: ["mesocycle_id","athlete_id"]
isOneToOne: false
      referencedRelation: "mesocycles"
      referencedColumns: ["id","athlete_id"]
    },{
      foreignKeyName: "training_days_mesocycle_id_template_fkey"
      columns: ["mesocycle_id","trainer_id","is_template"]
isOneToOne: false
      referencedRelation: "mesocycles"
      referencedColumns: ["id","trainer_id","is_template"]
    },{
      foreignKeyName: "training_days_trainer_id_fkey"
      columns: ["trainer_id"]
isOneToOne: false
      referencedRelation: "trainers"
      referencedColumns: ["profile_id"]
    }
                  ]
                }
          }
          Views: {
            [_ in never]: never
          }
          Functions: {
            "accept_invitation":
{ Args: Record<PropertyKey, never>; Returns: string
                           }
          }
          Enums: {
            [_ in never]: never
          }
          CompositeTypes: {
            [_ in never]: never
          }
        }
}

type DatabaseWithoutInternals = Omit<Database, '__InternalSupabase'>

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never
> = DefaultSchemaTableNameOrOptions extends { schema: keyof DatabaseWithoutInternals }
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
  ? (DefaultSchema["Tables"] & DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
      Row: infer R
    }
    ? R
    : never
  : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never
> = DefaultSchemaTableNameOrOptions extends { schema: keyof DatabaseWithoutInternals }
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
  ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
      Insert: infer I
    }
    ? I
    : never
  : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never
> = DefaultSchemaTableNameOrOptions extends { schema: keyof DatabaseWithoutInternals }
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
  ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
      Update: infer U
    }
    ? U
    : never
  : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never
> = DefaultSchemaEnumNameOrOptions extends { schema: keyof DatabaseWithoutInternals }
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
  ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
  : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never
> = PublicCompositeTypeNameOrOptions extends { schema: keyof DatabaseWithoutInternals }
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
  ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
  : never

export const Constants = {
  "public": {
          Enums: {
            
          }
        }
} as const
