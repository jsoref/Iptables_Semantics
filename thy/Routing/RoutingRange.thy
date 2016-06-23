theory RoutingRange
imports RoutingSet
begin

(* how is the IP space transformed when a rule applies? *)
definition range_prefix_match :: "'a::len prefix_match \<Rightarrow> 'a wordinterval \<Rightarrow> 'a wordinterval \<times> 'a wordinterval" where
  "range_prefix_match pfx rg \<equiv> (let pfxrg = prefix_to_wordinterval pfx in 
  (wordinterval_intersection rg pfxrg, wordinterval_setminus rg pfxrg))"
lemma range_prefix_match_set_eq:
  "(\<lambda>(r1,r2). (wordinterval_to_set r1, wordinterval_to_set r2)) (range_prefix_match pfx rg) =
    ipset_prefix_match pfx (wordinterval_to_set rg)"
  unfolding range_prefix_match_def ipset_prefix_match_def Let_def 
  using wordinterval_intersection_set_eq wordinterval_setminus_set_eq prefix_to_wordinterval_set_eq  by auto
lemma range_prefix_match_sm[simp]:  "wordinterval_to_set (fst (range_prefix_match pfx rg)) = 
    fst (ipset_prefix_match pfx (wordinterval_to_set rg))"
  by (metis fst_conv ipset_prefix_match_m  wordinterval_intersection_set_eq prefix_to_wordinterval_set_eq range_prefix_match_def)
lemma range_prefix_match_snm[simp]: "wordinterval_to_set (snd (range_prefix_match pfx rg)) =
    snd (ipset_prefix_match pfx (wordinterval_to_set rg))"
  by (metis snd_conv ipset_prefix_match_nm wordinterval_setminus_set_eq prefix_to_wordinterval_set_eq range_prefix_match_def)

type_synonym ipv4range = "32 wordinterval"

fun range_destination :: "prefix_routing \<Rightarrow> ipv4range \<Rightarrow> (ipv4range \<times> routing_action) list" where
"range_destination [] rg = (if wordinterval_empty rg then [] else [(rg, (routing_action (undefined::routing_rule)))])" |
"range_destination (r # rs) rg = (
  let rpm = range_prefix_match (routing_match r) rg in (let m = fst rpm in (let nm = snd rpm in (
    (if wordinterval_empty m  then [] else [ (m, routing_action r) ]) @ 
    (if wordinterval_empty nm then [] else range_destination rs nm)
))))"

lemma range_destination_eq:
  "{ (wordinterval_to_set r, ports)|r ports. (r, ports) \<in> set (range_destination rtbl rg)} = ipset_destination rtbl (wordinterval_to_set rg)"
apply(induction rtbl arbitrary: rg)
   apply(simp;fail)
  apply(simp only: Let_def range_destination.simps ipset_destination.simps)
  apply(case_tac "fst (ipset_prefix_match (routing_match a) (wordinterval_to_set rg)) = {}")
   apply(case_tac[!] "snd (ipset_prefix_match (routing_match a) (wordinterval_to_set rg)) = {}")
     apply(simp_all only: refl if_True if_False range_prefix_match_sm[symmetric] range_prefix_match_snm[symmetric] wordinterval_empty_set_eq Un_empty_left Un_empty_right)
     apply(simp_all)[3]
  apply(simp only: set_append set_simps)
  apply blast
done

definition "rr_to_sr r \<equiv> set (map (\<lambda>(x,y). (wordinterval_to_set x, y)) r)"

lemma range_destination_eq2:
  "wordinterval_to_set rg = rS \<Longrightarrow>
   ipset_destination rtbl rS = rr_to_sr (range_destination rtbl rg)"
  apply(unfold rr_to_sr_def)
  apply(induction rtbl arbitrary: rg rS)
   apply(simp)
  apply(simp only: Let_def range_destination.simps ipset_destination.simps)
  apply(case_tac "fst (ipset_prefix_match (routing_match a) (wordinterval_to_set rg)) = {}")
   apply(case_tac[!] "snd (ipset_prefix_match (routing_match a) (wordinterval_to_set rg)) = {}")
     apply(simp_all only: refl if_True if_False range_prefix_match_sm[symmetric] range_prefix_match_snm[symmetric] wordinterval_empty_set_eq Un_empty_left Un_empty_right)
     apply(simp_all)[3]
  proof -
    case goal1
    let ?maf = "(\<lambda>(x, y). (wordinterval_to_set x, y))"
    have ne: "wordinterval_to_set (fst (range_prefix_match (routing_match a) rg)) \<noteq> {}"
             "wordinterval_to_set (snd (range_prefix_match (routing_match a) rg)) \<noteq> {}"
      using goal1(3,4,2)  by simp_all
    have *: "snd (ipset_prefix_match (routing_match a) rS) = wordinterval_to_set (snd (range_prefix_match (routing_match a) rg))"
      using goal1(2) by simp
    have ***: "(fst (ipset_prefix_match (routing_match a) rS), routing_action a) =
      ?maf (fst (range_prefix_match (routing_match a) rg), routing_action a)" using goal1(2) by simp
    moreover
    have **: "ipset_destination rtbl (snd (ipset_prefix_match (routing_match a) rS)) =
      set (map ?maf (range_destination rtbl (snd (range_prefix_match (routing_match a) rg))))"
    using goal1(1)[OF *[symmetric]] by simp
    show ?case unfolding ** ***
     by(simp only: set_map set_append set_simps if_False image_Un ne image_empty image_insert)
  qed

definition "range_rel r = {(ip,port)|ip port rg. (rg,port) \<in> set r \<and> ip \<in> wordinterval_to_set rg}"
lemma in_range_rel: "in_rel (range_rel r) x y = (\<exists>rg. wordinterval_element x rg \<and> (rg,y) \<in> set r)"
  unfolding wordinterval_element_set_eq in_rel_def range_rel_def by auto
lemma range_rel_to_sr: "range_rel = ipset_rel \<circ> rr_to_sr"
  unfolding comp_def rr_to_sr_def
  unfolding fun_eq_iff
  unfolding range_rel_def ipset_rel_def
  by auto

lemma range_destination_correct:
  assumes v_pfx: "valid_prefixes rtbl"
  shows "(routing_table_semantics rtbl dst_a = ports) \<longleftrightarrow> in_rel (range_rel (range_destination rtbl ipv4range_UNIV)) dst_a ports"
  unfolding ipset_destination_correct[OF v_pfx UNIV_I] ipv4range_UNIV_set_eq[symmetric] range_destination_eq[symmetric] range_rel_def ipset_rel_def
  by simp blast

fun map_of_ranges where
"map_of_ranges [] = (\<lambda>x. undefined)" |
"map_of_ranges ((a,b)#rs) = (\<lambda>x. if wordinterval_element x a then b else map_of_ranges rs x)"

(*lemma "(map_of_ranges r a = b) = in_rel (range_rel r) a b"
unfolding in_rel_def range_rel_def
apply(induction r)
prefer 2
apply(clarify)
apply(unfold map_of_ranges.simps(2))
apply(case_tac "\<not>wordinterval_element a aa")
apply(unfold wordinterval_element_set_eq)
apply auto[1]
apply clarsimp
apply(rule)+
apply simp
apply simp
proof -
  fix aa ba
  assume "(map_of_ranges r a = b) = (\<exists>rg. (rg, b) \<in> set r \<and> a \<in> wordinterval_to_set rg)"
  assume "a \<in> wordinterval_to_set aa"
  assume " \<exists>rg. (rg = aa \<and> b = ba \<or> (rg, b) \<in> set r) \<and> a \<in> wordinterval_to_set rg"
  show "ba = b"*)

lemma range_left_side_nonempty: "x \<in> set (map fst (range_destination rtbl rg)) \<Longrightarrow> \<not> wordinterval_empty x"
proof -
  case goal1
  have "\<exists>S. S = wordinterval_to_set rg" by simp then guess S ..
  note * = range_destination_eq2[OF this[symmetric], unfolded rr_to_sr_def]
  show ?case
    unfolding wordinterval_empty_set_eq 
    using ipset_left_side_nonempty[where rg = S] unfolding * 
    using goal1 unfolding set_map
    by force
qed

subsection\<open>Reduction\<close>

definition "range_left_reduce \<equiv> list_left_reduce wordinterval_Union"
lemma range_left_reduce_set_eq: "rr_to_sr (range_left_reduce r) = left_reduce (rr_to_sr r)"
  by(fact list_left_reduce_set_eq[OF wordinterval_Union rr_to_sr_def, folded range_left_reduce_def])

lemma "range_rel r = range_rel (range_left_reduce r)"
  unfolding range_rel_to_sr
  unfolding comp_def
  unfolding range_left_reduce_set_eq
  using left_reduce_ipset_rel_stable .

definition "reduced_range_destination tbl r = range_left_reduce (range_destination tbl r)"
lemma reduced_range_destination_eq:
  assumes "wordinterval_to_set rg = rS"
  shows "reduced_ipset_destination rtbl rS = rr_to_sr (reduced_range_destination rtbl rg)"
  unfolding reduced_ipset_destination_def reduced_range_destination_def
  unfolding range_left_reduce_set_eq
  using arg_cong[OF range_destination_eq2[OF assms]]
  . (* goes by . and .. — weird *)

lemma reduced_range_destination_eq1: (* equality that was first proven. *)
  "{ (wordinterval_to_set r, ports)|r ports. (r, ports) \<in> set (reduced_range_destination rtbl rg)} = reduced_ipset_destination rtbl (wordinterval_to_set rg)"
  unfolding reduced_ipset_destination_def
  unfolding range_destination_eq[symmetric]
  unfolding reduced_range_destination_def
  using range_left_reduce_set_eq[unfolded rr_to_sr_def set_map, of "range_destination rtbl rg"]
  unfolding image_set_comprehension by simp

subsection\<open>Formulation\<close>

lemma in_rr_to_sr: "(xs, y) \<in> set foo \<Longrightarrow> (wordinterval_to_set xs, y) \<in> rr_to_sr foo"
  by(force simp add: rr_to_sr_def)

lemma rrd_subsets: "(x,y) \<in> set (reduced_range_destination rtbl rg) \<Longrightarrow> wordinterval_subset x rg"
proof goal_cases
  case 1
  { fix x xa
    assume "(xa, y) \<in> set (range_destination rtbl rg)"
    hence "(wordinterval_to_set xa, y) \<in> (ipset_destination rtbl (wordinterval_to_set rg))"
      using range_destination_eq by fastforce
    hence "x \<in> wordinterval_to_set xa
              \<Longrightarrow> x \<in> wordinterval_to_set rg"
      using ipset_destination_subsets by fastforce
  } note * = this
  show ?thesis using 1
    unfolding reduced_range_destination_def range_left_reduce_def
    unfolding list_left_reduce_def
    by(clarsimp simp add: image_iff wordinterval_Union list_domain_for_eq domain_for_def *)
qed

theorem "valid_prefixes rtbl \<Longrightarrow>
  (xs,y) \<in> set (reduced_range_destination rtbl rg) \<Longrightarrow> 
  x \<in> wordinterval_to_set xs \<Longrightarrow> 
  routing_table_semantics rtbl x = y"
proof goal_cases
  case 1
  def xs' \<equiv> "wordinterval_to_set xs"
  with 1(3) have i: "x \<in> xs'" by simp
  hence ir: "x \<in> wordinterval_to_set rg" using 1(2) unfolding xs'_def using rrd_subsets by force
  from 1(2) have "(xs', y) \<in> reduced_ipset_destination rtbl (wordinterval_to_set rg)"
    by(simp add: reduced_range_destination_eq xs'_def in_rr_to_sr)
  hence "(x, y) \<in> ipset_rel (reduced_ipset_destination rtbl (wordinterval_to_set rg))" unfolding ipset_rel_def
  using i by blast
  thus ?thesis using reduced_ipset_destination_correct[OF 1(1) ir] by simp
qed

theorem "valid_prefixes rtbl \<Longrightarrow>
  x \<in> wordinterval_to_set rg \<Longrightarrow>
  routing_table_semantics rtbl x = y \<Longrightarrow>
  \<exists>xs. (xs,y) \<in> set (reduced_range_destination rtbl rg) \<and>  x \<in> wordinterval_to_set xs"
by(simp add: reduced_ipset_destination_correct reduced_range_destination_eq1[symmetric] ipset_rel_def) blast

end
